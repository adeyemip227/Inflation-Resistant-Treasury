# Inflation-Adjusted Savings Protocol

A smart contract system built on Stacks blockchain that automatically adjusts savings goals and returns based on inflation rates to preserve and grow purchasing power over time.

## Overview

Traditional savings accounts lose purchasing power during inflationary periods. This protocol addresses this challenge by:

- **Inflation-Adjusted Returns**: Automatically adjusts interest rates to beat inflation
- **Real-Time Purchasing Power Tracking**: Monitors actual buying power of your savings
- **Smart Savings Goals**: Auto-adjusts targets based on inflation data
- **Time-Locked Deposits**: Earn bonus interest for commitment periods
- **Oracle-Based Inflation Data**: Uses reliable external data feeds

## Features

### 🏦 Core Savings Account
- Create inflation-resistant savings accounts
- Automatic compound interest calculation
- Real-time purchasing power preservation
- Transparent balance tracking (nominal vs. real value)

### 🎯 Smart Savings Goals
- Set financial targets with inflation protection
- Auto-adjustment option for changing economic conditions
- Progress tracking with real purchasing power metrics
- Achievement notifications and milestones

### 🔒 Time-Locked Deposits
- Earn bonus interest for locking funds
- Flexible lock periods (minimum 1 day)
- Early withdrawal protection
- Compound bonus calculations

### 📊 Inflation Oracle Integration
- Real-time inflation rate updates
- Historical inflation data storage
- Cumulative inflation factor tracking
- Oracle update frequency controls

## Contract Architecture

### Data Structures

```clarity
;; User savings accounts
savings-accounts: {
  balance: uint,              // Current nominal balance
  real-balance: uint,         // Inflation-adjusted balance
  total-deposited: uint,      // Historical deposits
  compound-interest-rate: uint // Current effective rate
}

;; Savings goals with inflation protection
savings-goals: {
  target-amount: uint,        // Original target
  adjusted-target: uint,      // Inflation-adjusted target
  current-amount: uint,       // Progress toward goal
  auto-adjust: bool          // Enable automatic adjustments
}

;; Time-locked deposits
time-locked-deposits: {
  amount: uint,              // Locked amount
  lock-period: uint,         // Lock duration in blocks
  bonus-rate: uint,          // Additional interest rate
  withdrawn: bool            // Withdrawal status
}
```

### Key Constants

```clarity
PRECISION-FACTOR: 10000     // 4 decimal places (100.00%)
MIN-LOCK-PERIOD: 144        // ~1 day in blocks
ORACLE-UPDATE-COOLDOWN: 144 // Minimum update frequency
```

## Usage Examples

### 1. Create Savings Account

```clarity
;; Create a new inflation-adjusted savings account
(contract-call? .inflation-savings create-savings-account)
```

### 2. Make Deposits

```clarity
;; Regular deposit
(contract-call? .inflation-savings deposit u1000000) ;; 10 STX

;; Time-locked deposit with 5% bonus for 30 days
(contract-call? .inflation-savings deposit-with-lock 
  u1000000    ;; amount: 10 STX
  u4320       ;; lock-blocks: ~30 days
  u500)       ;; bonus-rate: 5%
```

### 3. Set Savings Goals

```clarity
;; Create emergency fund goal with auto-adjustment
(contract-call? .inflation-savings create-savings-goal
  u10000000   ;; target: 100 STX
  u52560      ;; target-date: ~1 year
  "Emergency Fund"
  true)       ;; auto-adjust for inflation

;; Allocate funds to goal
(contract-call? .inflation-savings allocate-to-goal u1 u2000000) ;; 20 STX
```

### 4. Oracle Updates (Contract Owner Only)

```clarity
;; Update inflation rate to 3.5% annually
(contract-call? .inflation-savings update-inflation-rate 
  u350        ;; 3.5% in basis points
  u1440)      ;; period in blocks
```

## Read-Only Functions

### Account Information
```clarity
(contract-call? .inflation-savings get-account-info 'ST1EXAMPLE...)
;; Returns: balance, real-balance, purchasing-power, effective-interest-rate
```

### Savings Goal Progress
```clarity
(contract-call? .inflation-savings get-savings-goal 'ST1EXAMPLE... u1)
;; Returns: progress-percentage, adjusted-target, is-achieved
```

### Inflation Data
```clarity
(contract-call? .inflation-savings get-inflation-info)
;; Returns: current-rate, cumulative-factor, last-update
```

### Purchasing Power Analysis
```clarity
(contract-call? .inflation-savings calculate-real-value u1000000 u1000)
;; Returns: real-value, purchasing-power-loss, inflation-factor
```

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | ERR-NOT-AUTHORIZED | Caller not authorized for operation |
| u101 | ERR-ACCOUNT-NOT-FOUND | Savings account doesn't exist |
| u102 | ERR-INSUFFICIENT-BALANCE | Not enough funds for operation |
| u103 | ERR-INVALID-AMOUNT | Amount must be greater than zero |
| u104 | ERR-GOAL-NOT-FOUND | Savings goal doesn't exist |
| u105 | ERR-GOAL-ALREADY-REACHED | Goal already achieved |
| u106 | ERR-WITHDRAWAL-TOO-EARLY | Time-lock period not expired |
| u107 | ERR-INVALID-INFLATION-RATE | Inflation rate exceeds maximum |
| u108 | ERR-ORACLE-UPDATE-TOO-FREQUENT | Oracle update too soon |

## Testing

The protocol includes comprehensive unit tests using Vitest:

```bash
# Install dependencies
npm install

# Run tests
npm test

# Run tests with coverage
npm run test:coverage
```

### Test Coverage

- ✅ Account creation and management
- ✅ Deposit and withdrawal operations  
- ✅ Time-locked deposits with bonuses
- ✅ Savings goals with inflation adjustments
- ✅ Oracle inflation rate updates
- ✅ Purchasing power calculations
- ✅ Error handling and validation
- ✅ Interest rate calculations
- ✅ Precision and constant validation

## Security Considerations

### Oracle Security
- Only contract owner can update inflation rates
- Rate updates have cooldown periods
- Maximum inflation rate limits (20%)
- Historical data immutability

### Financial Safety
- Withdrawal validations prevent overdrafts
- Time-lock enforcement prevents early withdrawal
- Precision factors prevent rounding errors
- Balance consistency checks

### Access Control
- User-specific account isolation
- Goal ownership verification
- Deposit ownership tracking

## Deployment

### Prerequisites
- Stacks CLI installed
- Testnet/Mainnet STX for deployment
- Configured Stacks account

### Deploy Steps

```bash
# Test on testnet first
clarinet deploy --testnet

# Deploy to mainnet
clarinet deploy --mainnet
```

### Post-Deployment Setup

1. **Initialize Oracle**: Set initial inflation rate
2. **Configure Parameters**: Adjust base interest rates if needed
3. **Test Operations**: Verify core functionality
4. **Monitor Performance**: Track inflation adjustments

## Economic Model

### Interest Rate Calculation
```
Effective Rate = Base Rate + Inflation Bonus + Time Lock Bonus
Inflation Bonus = Current Inflation Rate × 0.5
```

### Purchasing Power Preservation
```
Real Balance = Nominal Balance ÷ Cumulative Inflation Factor
Purchasing Power = Real Balance ÷ Current Inflation Factor
```

### Time Lock Bonuses
```
Bonus = (Amount × Bonus Rate × Lock Years) ÷ Precision Factor
Total Return = Principal + Interest + Time Lock Bonus
```

## Roadmap

### Phase 1 (Current)
- ✅ Core savings functionality
- ✅ Inflation oracle integration
- ✅ Time-locked deposits
- ✅ Basic savings goals

### Phase 2 (Planned)
- 🔄 Multi-token support (SIP-010)
- 🔄 Advanced goal types (recurring, milestone-based)
- 🔄 Social savings challenges
- 🔄 DeFi yield integration

### Phase 3 (Future)
- 📋 Mobile app interface
- 📋 Automated DCA strategies
- 📋 Cross-chain inflation oracles
- 📋 Governance token integration

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for new functionality
4. Ensure all tests pass (`npm test`)
5. Commit changes (`git commit -m 'Add amazing feature'`)
6. Push to branch (`git push origin feature/amazing-feature`)
7. Open Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Documentation**: [docs.inflation-savings.com](https://docs.inflation-savings.com)
- **Discord**: [Join our community](https://discord.gg/inflation-savings)
- **GitHub Issues**: [Report bugs](https://github.com/user/inflation-savings/issues)
- **Email**: support@inflation-savings.com

## Disclaimer

This smart contract handles financial assets. Users should:
- Understand inflation and interest rate risks
- Test on testnet before mainnet usage
- Never invest more than they can afford to lose
- Conduct independent security audits for production use

**This software is provided "as is" without warranty of any kind.**