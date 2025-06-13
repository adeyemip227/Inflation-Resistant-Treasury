;; Inflation-Adjusted Savings Protocol
;; A smart contract system that adjusts savings goals and returns based on inflation rates
;; to preserve and grow purchasing power over time

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ACCOUNT-NOT-FOUND (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-GOAL-NOT-FOUND (err u104))
(define-constant ERR-GOAL-ALREADY-REACHED (err u105))
(define-constant ERR-WITHDRAWAL-TOO-EARLY (err u106))
(define-constant ERR-INVALID-INFLATION-RATE (err u107))
(define-constant ERR-ORACLE-UPDATE-TOO-FREQUENT (err u108))

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant PRECISION-FACTOR u10000) ;; 4 decimal places (10000 = 100.00%)
(define-constant MIN-LOCK-PERIOD u144) ;; ~1 day in blocks (assuming 10min blocks)
(define-constant ORACLE-UPDATE-COOLDOWN u144) ;; Minimum blocks between oracle updates

;; Data structures
(define-map savings-accounts 
  principal 
  {
    balance: uint,
    real-balance: uint, ;; inflation-adjusted balance
    total-deposited: uint,
    account-created: uint,
    last-adjustment: uint,
    compound-interest-rate: uint, ;; annual rate in basis points (500 = 5%)
    last-compound: uint
  }
)

(define-map savings-goals 
  {owner: principal, goal-id: uint}
  {
    target-amount: uint, ;; original target amount
    adjusted-target: uint, ;; inflation-adjusted target
    current-amount: uint,
    goal-name: (string-ascii 64),
    target-date: uint, ;; block height
    created-date: uint,
    is-achieved: bool,
    auto-adjust: bool
  }
)

(define-map inflation-data
  uint ;; block height (rounded to periods)
  {
    inflation-rate: uint, ;; annual inflation rate in basis points
    cumulative-inflation: uint, ;; cumulative inflation since contract deployment
    updated-by: principal,
    timestamp: uint
  }
)

(define-map time-locked-deposits
  {owner: principal, deposit-id: uint}
  {
    amount: uint,
    lock-period: uint, ;; blocks
    deposit-block: uint,
    bonus-rate: uint, ;; additional interest for locking
    withdrawn: bool
  }
)

;; Global state
(define-data-var current-inflation-rate uint u200) ;; 2% default
(define-data-var cumulative-inflation-factor uint PRECISION-FACTOR) ;; starts at 100%
(define-data-var base-interest-rate uint u300) ;; 3% base annual rate
(define-data-var last-oracle-update uint u0)
(define-data-var next-goal-id uint u1)
(define-data-var next-deposit-id uint u1)

;; Oracle functions (for inflation data updates)
(define-public (update-inflation-rate (new-rate uint) (period-blocks uint))
  (let (
    (current-block stacks-block-height)
    (last-update (var-get last-oracle-update))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-rate u2000) ERR-INVALID-INFLATION-RATE) ;; max 20% inflation
    (asserts! (>= (- current-block last-update) ORACLE-UPDATE-COOLDOWN) ERR-ORACLE-UPDATE-TOO-FREQUENT)
    
    ;; Update cumulative inflation factor
    (let (
      (current-factor (var-get cumulative-inflation-factor))
      (period-factor (+ PRECISION-FACTOR (/ (* new-rate period-blocks) u52560))) ;; ~1 year in blocks
      (new-cumulative (/ (* current-factor period-factor) PRECISION-FACTOR))
    )
      (var-set current-inflation-rate new-rate)
      (var-set cumulative-inflation-factor new-cumulative)
      (var-set last-oracle-update current-block)
      
      ;; Store historical data
      (map-set inflation-data (/ current-block u1440) {
        inflation-rate: new-rate,
        cumulative-inflation: new-cumulative,
        updated-by: tx-sender,
        timestamp: current-block
      })
      
      (ok new-cumulative)
    )
  )
)

;; Account management
(define-public (create-savings-account)
  (let ((existing-account (map-get? savings-accounts tx-sender)))
    (asserts! (is-none existing-account) ERR-ACCOUNT-NOT-FOUND)
    (map-set savings-accounts tx-sender {
      balance: u0,
      real-balance: u0,
      total-deposited: u0,
      account-created: stacks-block-height,
      last-adjustment: stacks-block-height,
      compound-interest-rate: (var-get base-interest-rate),
      last-compound: stacks-block-height
    })
    (ok true)
  )
)

;; Deposit functions
(define-public (deposit (amount uint))
  (let ((account (unwrap! (map-get? savings-accounts tx-sender) ERR-ACCOUNT-NOT-FOUND)))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Apply compound interest and inflation adjustment before deposit
    (let ((updated-account (apply-compound-interest-and-inflation account tx-sender)))
      (map-set savings-accounts tx-sender {
        balance: (+ (get balance updated-account) amount),
        real-balance: (+ (get real-balance updated-account) amount),
        total-deposited: (+ (get total-deposited updated-account) amount),
        account-created: (get account-created updated-account),
        last-adjustment: stacks-block-height,
        compound-interest-rate: (get compound-interest-rate updated-account),
        last-compound: stacks-block-height
      })
      
      ;; In a real implementation, this would transfer STX from user
      ;; (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      
      (ok amount)
    )
  )
)

;; Time-locked deposit with bonus interest
(define-public (deposit-with-lock (amount uint) (lock-blocks uint) (bonus-rate uint))
  (let (
    (account (unwrap! (map-get? savings-accounts tx-sender) ERR-ACCOUNT-NOT-FOUND))
    (deposit-id (var-get next-deposit-id))
  )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= lock-blocks MIN-LOCK-PERIOD) ERR-WITHDRAWAL-TOO-EARLY)
    (asserts! (<= bonus-rate u1000) ERR-INVALID-AMOUNT) ;; max 10% bonus
    
    ;; Create locked deposit record
    (map-set time-locked-deposits {owner: tx-sender, deposit-id: deposit-id} {
      amount: amount,
      lock-period: lock-blocks,
      deposit-block: stacks-block-height,
      bonus-rate: bonus-rate,
      withdrawn: false
    })
    
    ;; Update account
    (try! (deposit amount))
    (var-set next-deposit-id (+ deposit-id u1))
    
    (ok deposit-id)
  )
)

;; Withdraw functions
(define-public (withdraw (amount uint))
  (let ((account (unwrap! (map-get? savings-accounts tx-sender) ERR-ACCOUNT-NOT-FOUND)))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Apply compound interest and inflation adjustment
    (let ((updated-account (apply-compound-interest-and-inflation account tx-sender)))
      (asserts! (>= (get balance updated-account) amount) ERR-INSUFFICIENT-BALANCE)
      
      (map-set savings-accounts tx-sender {
        balance: (- (get balance updated-account) amount),
        real-balance: (- (get real-balance updated-account) amount),
        total-deposited: (get total-deposited updated-account),
        account-created: (get account-created updated-account),
        last-adjustment: stacks-block-height,
        compound-interest-rate: (get compound-interest-rate updated-account),
        last-compound: stacks-block-height
      })
      
      ;; In a real implementation, this would transfer STX to user
      ;; (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
      
      (ok amount)
    )
  )
)

;; Withdraw from time-locked deposit
(define-public (withdraw-locked-deposit (deposit-id uint))
  (let (
    (locked-deposit (unwrap! (map-get? time-locked-deposits {owner: tx-sender, deposit-id: deposit-id}) ERR-GOAL-NOT-FOUND))
    (unlock-block (+ (get deposit-block locked-deposit) (get lock-period locked-deposit)))
  )
    (asserts! (not (get withdrawn locked-deposit)) ERR-GOAL-ALREADY-REACHED)
    (asserts! (>= stacks-block-height unlock-block) ERR-WITHDRAWAL-TOO-EARLY)
    
    ;; Calculate bonus interest
    (let (
      (base-amount (get amount locked-deposit))
      (bonus-interest (calculate-time-lock-bonus locked-deposit))
      (total-amount (+ base-amount bonus-interest))
    )
      ;; Mark as withdrawn
      (map-set time-locked-deposits {owner: tx-sender, deposit-id: deposit-id}
        (merge locked-deposit {withdrawn: true}))
      
      ;; Add bonus to account (base amount already there from initial deposit)
      (let ((account (unwrap! (map-get? savings-accounts tx-sender) ERR-ACCOUNT-NOT-FOUND)))
        (map-set savings-accounts tx-sender
          (merge account {
            balance: (+ (get balance account) bonus-interest),
            real-balance: (+ (get real-balance account) bonus-interest)
          }))
      )
      
      (ok total-amount)
    )
  )
)

;; Savings goals management
(define-public (create-savings-goal (target-amount uint) (target-date uint) (goal-name (string-ascii 64)) (auto-adjust bool))
  (let ((goal-id (var-get next-goal-id)))
    (asserts! (> target-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> target-date stacks-block-height) ERR-INVALID-AMOUNT)
    
    (map-set savings-goals {owner: tx-sender, goal-id: goal-id} {
      target-amount: target-amount,
      adjusted-target: target-amount,
      current-amount: u0,
      goal-name: goal-name,
      target-date: target-date,
      created-date: stacks-block-height,
      is-achieved: false,
      auto-adjust: auto-adjust
    })
    
    (var-set next-goal-id (+ goal-id u1))
    (ok goal-id)
  )
)

;; Allocate savings to goal
(define-public (allocate-to-goal (goal-id uint) (amount uint))
  (let (
    (goal (unwrap! (map-get? savings-goals {owner: tx-sender, goal-id: goal-id}) ERR-GOAL-NOT-FOUND))
    (account (unwrap! (map-get? savings-accounts tx-sender) ERR-ACCOUNT-NOT-FOUND))
  )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (get balance account) amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (not (get is-achieved goal)) ERR-GOAL-ALREADY-REACHED)
    
    ;; Update goal progress
    (let (
      (new-current (+ (get current-amount goal) amount))
      (adjusted-target (if (get auto-adjust goal) 
                        (adjust-target-for-inflation (get target-amount goal) (get created-date goal))
                        (get target-amount goal)))
    )
      (map-set savings-goals {owner: tx-sender, goal-id: goal-id}
        (merge goal {
          current-amount: new-current,
          adjusted-target: adjusted-target,
          is-achieved: (>= new-current adjusted-target)
        }))
      
      ;; Update account balance
      (map-set savings-accounts tx-sender
        (merge account {balance: (- (get balance account) amount)}))
      
      (ok new-current)
    )
  )
)

;; Helper functions
(define-private (apply-compound-interest-and-inflation (account {balance: uint, real-balance: uint, total-deposited: uint, account-created: uint, last-adjustment: uint, compound-interest-rate: uint, last-compound: uint}) (owner principal))
  (let (
    (blocks-since-compound (- stacks-block-height (get last-compound account)))
    (compound-factor (calculate-compound-factor (get compound-interest-rate account) blocks-since-compound))
    (inflation-adjustment (calculate-inflation-adjustment (get last-adjustment account)))
  )
    ;; Apply compound interest
    (let (
      (new-balance (/ (* (get balance account) compound-factor) PRECISION-FACTOR))
      (inflation-adjusted-balance (/ (* new-balance PRECISION-FACTOR) inflation-adjustment))
    )
      {
        balance: new-balance,
        real-balance: inflation-adjusted-balance,
        total-deposited: (get total-deposited account),
        account-created: (get account-created account),
        last-adjustment: stacks-block-height,
        compound-interest-rate: (+ (get compound-interest-rate account) (calculate-inflation-bonus)),
        last-compound: stacks-block-height
      }
    )
  )
)

(define-private (calculate-compound-factor (annual-rate uint) (blocks uint))
  ;; Simple compound interest: (1 + r)^t where t is fraction of year
  ;; Approximated for small periods
  (let ((period-rate (/ (* annual-rate blocks) u52560))) ;; ~1 year in blocks
    (+ PRECISION-FACTOR period-rate)
  )
)

(define-private (calculate-inflation-adjustment (last-update uint))
  (let (
    (blocks-since-update (- stacks-block-height last-update))
    (current-rate (var-get current-inflation-rate))
    (period-inflation (/ (* current-rate blocks-since-update) u52560))
  )
    (+ PRECISION-FACTOR period-inflation)
  )
)

(define-private (calculate-inflation-bonus)
  ;; Bonus interest rate to help beat inflation
  (let ((current-inflation (var-get current-inflation-rate)))
    (/ current-inflation u2) ;; 50% of inflation rate as bonus
  )
)

(define-private (adjust-target-for-inflation (original-target uint) (created-date uint))
  (let (
    (blocks-elapsed (- stacks-block-height created-date))
    (inflation-factor (calculate-inflation-adjustment created-date))
  )
    (/ (* original-target inflation-factor) PRECISION-FACTOR)
  )
)

(define-private (calculate-time-lock-bonus (locked-deposit {amount: uint, lock-period: uint, deposit-block: uint, bonus-rate: uint, withdrawn: bool}))
  (let (
    (lock-years (/ (get lock-period locked-deposit) u52560)) ;; Convert blocks to years
    (annual-bonus (/ (* (get amount locked-deposit) (get bonus-rate locked-deposit)) PRECISION-FACTOR))
  )
    (* annual-bonus lock-years)
  )
)

;; Read-only functions
(define-read-only (get-account-info (owner principal))
  (match (map-get? savings-accounts owner)
    account
    (let ((updated-account (apply-compound-interest-and-inflation account owner)))
      (ok {
        balance: (get balance updated-account),
        real-balance: (get real-balance updated-account),
        purchasing-power: (/ (* (get real-balance updated-account) PRECISION-FACTOR) (var-get cumulative-inflation-factor)),
        total-deposited: (get total-deposited updated-account),
        account-created: (get account-created updated-account),
        effective-interest-rate: (get compound-interest-rate updated-account)
      })
    )
    ERR-ACCOUNT-NOT-FOUND
  )
)

(define-read-only (get-savings-goal (owner principal) (goal-id uint))
  (match (map-get? savings-goals {owner: owner, goal-id: goal-id})
    goal
    (let (
      (adjusted-target (if (get auto-adjust goal)
                        (adjust-target-for-inflation (get target-amount goal) (get created-date goal))
                        (get target-amount goal)))
      (progress (if (> adjusted-target u0) (/ (* (get current-amount goal) u100) adjusted-target) u0))
    )
      (ok {
        target-amount: (get target-amount goal),
        adjusted-target: adjusted-target,
        current-amount: (get current-amount goal),
        progress-percentage: progress,
        goal-name: (get goal-name goal),
        target-date: (get target-date goal),
        is-achieved: (>= (get current-amount goal) adjusted-target),
        auto-adjust: (get auto-adjust goal)
      })
    )
    ERR-GOAL-NOT-FOUND
  )
)

(define-read-only (get-inflation-info)
  {
    current-rate: (var-get current-inflation-rate),
    cumulative-factor: (var-get cumulative-inflation-factor),
    base-interest-rate: (var-get base-interest-rate),
    last-update: (var-get last-oracle-update)
  }
)

(define-read-only (get-locked-deposit (owner principal) (deposit-id uint))
  (match (map-get? time-locked-deposits {owner: owner, deposit-id: deposit-id})
    locked-deposit
    (let (
      (unlock-block (+ (get deposit-block locked-deposit) (get lock-period locked-deposit)))
      (bonus-interest (calculate-time-lock-bonus locked-deposit))
    )
      (ok {
        amount: (get amount locked-deposit),
        lock-period: (get lock-period locked-deposit),
        deposit-block: (get deposit-block locked-deposit),
        unlock-block: unlock-block,
        bonus-rate: (get bonus-rate locked-deposit),
        projected-bonus: bonus-interest,
        withdrawn: (get withdrawn locked-deposit),
        can-withdraw: (>= stacks-block-height unlock-block)
      })
    )
    ERR-GOAL-NOT-FOUND
  )
)

;; Calculate purchasing power over time
(define-read-only (calculate-real-value (nominal-amount uint) (from-block uint))
  (let (
    (inflation-since (calculate-inflation-adjustment from-block))
    (real-value (/ (* nominal-amount PRECISION-FACTOR) inflation-since))
  )
    (ok {
      nominal-amount: nominal-amount,
      real-value: real-value,
      purchasing-power-loss: (- nominal-amount real-value),
      inflation-factor: inflation-since
    })
  )
)