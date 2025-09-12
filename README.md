# Mental Health Support DAO 🧠💚

A decentralized autonomous organization that facilitates peer-to-peer mental health counseling sessions using blockchain technology and token-based payments.

## 🌟 Features

- **🩺 Counselor Registration**: Mental health professionals can register and set their session rates
- **📅 Session Booking**: Clients can book and pay for counseling sessions using therapy tokens  
- **🏛️ DAO Governance**: Token holders can create and vote on proposals to improve the platform
- **⭐ Rating System**: Clients can rate counselors to maintain service quality
- **💰 Token Economy**: Native therapy tokens power all transactions and voting

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
git clone https://github.com/gracechelsea172/Mental-Health-Support-DAO
cd Mental-Health-Support-DAO
clarinet console
```

## 📖 Usage Guide

### For Counselors 👨‍⚕️👩‍⚕️

**Register as a counselor:**
```clarity
(contract-call? .Mental-Health-Support-DAO register-counselor "Dr. Smith" "Anxiety and Depression" u50)
```

**Update your session rate:**
```clarity
(contract-call? .Mental-Health-Support-DAO update-counselor-rate u60)
```

**Complete a session:**
```clarity
(contract-call? .Mental-Health-Support-DAO complete-session u1)
```

### For Clients 🧑‍🤝‍🧑

**Book a counseling session:**
```clarity
(contract-call? .Mental-Health-Support-DAO book-session 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM u1640995200 u60)
```

**Cancel a session:**
```clarity
(contract-call? .Mental-Health-Support-DAO cancel-session u1)
```

**Rate a counselor:**
```clarity
(contract-call? .Mental-Health-Support-DAO rate-counselor 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM u85)
```

### For DAO Members 🏛️

**Join the DAO:**
```clarity
(contract-call? .Mental-Health-Support-DAO join-dao)
```

**Create a proposal:**
```clarity
(contract-call? .Mental-Health-Support-DAO create-proposal "Reduce session fees" "Proposal to reduce minimum session fees to increase accessibility")
```

**Vote on proposals:**
```clarity
(contract-call? .Mental-Health-Support-DAO vote-on-proposal u1 true)
```

## 🔍 Read-Only Functions

**Check counselor details:**
```clarity
(contract-call? .Mental-Health-Support-DAO get-counselor 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

**View session information:**
```clarity
(contract-call? .Mental-Health-Support-DAO get-session u1)
```

**Check token balance:**
```clarity
(contract-call? .Mental-Health-Support-DAO get-token-balance 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## 🏗️ Contract Structure

### Data Maps
- `counselors`: Stores counselor profiles and ratings
- `sessions`: Tracks all counseling sessions
- `dao-members`: DAO membership and voting power
- `proposals`: Governance proposals and voting results

### Key Functions
- Session management (book, complete, cancel)
- Counselor registration and rating
- DAO governance (proposals, voting)
- Token operations and transfers

## 🧪 Testing

```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For support and questions, please open an issue in the repository or contact the development team.

---

*Building a healthier world through decentralized mental health support* 🌍💚
