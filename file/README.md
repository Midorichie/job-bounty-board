# Job Bounty Board - Decentralized Task Marketplace

A secure, decentralized job bounty board built on the Stacks blockchain using Clarity smart contracts. This platform enables trustless task posting, submission, and payment with built-in escrow, reputation system, and dispute resolution.

## 🚀 Features

### Core Functionality
- **Task Posting**: Create bounty tasks with deadline and category classification
- **Secure Escrow**: Automatic fund holding until task completion
- **Proof of Work**: Workers submit proof of task completion
- **Reputation System**: Track user performance and build trust
- **Dispute Resolution**: Built-in mechanism for handling conflicts

### Security Enhancements
- **Escrow Protection**: Funds locked in contract until approval
- **Deadline Enforcement**: Tasks expire if not completed in time
- **Minimum Bounty**: Prevents spam with 1 STX minimum requirement
- **Fee Collection**: Sustainable 5% platform fee
- **Access Control**: Role-based permissions for sensitive operations

### New Features (Phase 2)
- **Task Categories**: Organize tasks by type (development, design, writing, etc.)
- **Dispute System**: 24-hour dispute window with arbitration
- **Task Cancellation**: Cancel tasks before worker assignment
- **Enhanced Reputation**: Detailed user statistics and ratings
- **Contract Statistics**: Platform-wide metrics and analytics

## 📋 Smart Contract Functions

### Public Functions

#### Task Management
- `post-task(title, description, bounty, deadline, category)` - Create a new bounty task
- `submit-task(id, proof)` - Submit proof of task completion
- `approve-task(id)` - Approve completed task and release payment
- `cancel-task(id)` - Cancel task before worker assignment

#### Dispute Resolution
- `dispute-task(id, reason)` - Initiate dispute within 24-hour window
- `resolve-dispute(id, award-to-worker)` - Contract owner resolves disputes

#### Admin Functions
- `set-contract-fee(new-fee)` - Update platform fee (max 10%)
- `add-task-category(category)` - Add new task categories

### Read-Only Functions
- `get-task(id)` - Retrieve task details
- `get-user-reputation(user)` - Get user reputation data
- `get-task-count()` - Total number of tasks created
- `get-contract-stats()` - Platform statistics
- `get-dispute-info(task-id)` - Dispute information

## 🛠️ Installation & Setup

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) v1.8.0+
- [Stacks CLI](https://docs.stacks.co/docs/clarity/using-stacks-cli)
- Node.js v16+ (for frontend development)

### Local Development

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/job-bounty-board.git
cd job-bounty-board
```

2. **Install Clarinet** (if not already installed)
```bash
curl -L https://github.com/hirosystems/clarinet/releases/download/v1.8.0/clarinet-linux-x64.tar.gz | tar xz
sudo mv clarinet /usr/local/bin
```

3. **Check project structure**
```bash
clarinet check
```

4. **Run tests**
```bash
clarinet test
```

5. **Start local devnet**
```bash
clarinet integrate
```

## 🧪 Testing

### Unit Tests
```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/job-bounty-board_test.ts

# Run with coverage
clarinet test --coverage
```

### Integration Tests
```bash
# Start devnet for integration testing
clarinet integrate

# Run integration tests
npm run test:integration
```

## 📊 Contract Architecture

### Data Structures

#### Task Structure
```clarity
{
  title: (string-ascii 50),
  description: (string-ascii 200),
  poster: principal,
  bounty: uint,
  is-completed: bool,
  worker: (optional principal),
  proof: (optional (string-ascii 200)),
  created-at: uint,
  deadline: uint,
  dispute-deadline: (optional uint),
  is-disputed: bool,
  category: (string-ascii 20)
}
```

#### Reputation Structure
```clarity
{
  completed-tasks: uint,
  total-earnings: uint,
  disputes-won: uint,
  disputes-lost: uint,
  rating: uint  ; Out of 100
}
```

### Error Codes
- `u100` - Task not found
- `u101` - Not authorized
- `u102` - Already submitted
- `u103` - Task already approved
- `u104` - Insufficient balance
- `u105` - No worker assigned
- `u106` - Task expired
- `u107` - Invalid bounty
- `u108` - Task disputed
- `u109` - Not worker
- `u110` - Dispute deadline passed

## �� Security Considerations

### Implemented Safeguards
1. **Escrow Protection**: Funds locked in contract until completion
2. **Deadline Validation**: Tasks must have valid future deadlines
3. **Minimum Bounty**: Prevents spam with 1 STX minimum
4. **Access Control**: Function-level authorization checks
5. **Dispute Window**: Limited time for dispute initiation
6. **Fee Cap**: Maximum 10% platform fee limit

### Best Practices
- Always check task existence before operations
- Validate user permissions for sensitive functions
- Use escrow for all financial transactions
- Implement proper error handling
- Regular security audits recommended

## 📈 Usage Examples

### Posting a Task
```clarity
(contract-call? .job-bounty-board post-task 
  "Build a React dApp" 
  "Create a simple React frontend for this contract"
  u10000000  ; 10 STX
  u4464      ; Block height deadline
  "development")
```

### Submitting Work
```clarity
(contract-call? .job-bounty-board submit-task 
  u1 
  "GitHub repo: https://github.com/user/react-dapp")
```

### Approving Task
```clarity
(contract-call? .job-bounty-board approve-task u1)
```

## 🚀 Deployment

### Testnet Deployment
```bash
clarinet deploy --network testnet
```

### Mainnet Deployment
```bash
clarinet deploy --network mainnet
```

## 📝 Changelog

### Version 2.0.0 (Phase 2)
- **Added**: Task categories and organization
- **Added**: Dispute resolution system
- **Added**: User reputation tracking
- **Added**: Task cancellation functionality
- **Added**: Enhanced security validations
- **Added**: Comprehensive error handling
- **Fixed**: Escrow mechanism for secure payments
- **Fixed**: Deadline validation and enforcement
- **Enhanced**: Contract statistics and analytics

### Version 1.0.0 (Phase 1)
- Basic task posting and submission
- Simple approval mechanism
- Initial smart contract structure

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## �� Acknowledgments

- Stacks Foundation for the blockchain infrastructure
- Clarity language development team
- Community contributors and testers

## 📞 Support

- **Documentation**: [Stacks Documentation](https://docs.stacks.co/)
- **Community**: [Discord](https://discord.gg/stacks)
- **Issues**: [GitHub Issues](https://github.com/yourusername/job-bounty-board/issues)

---

