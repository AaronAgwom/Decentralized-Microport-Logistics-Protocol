A Web3-based logistics coordination platform connecting remote areas with community drivers and local transport solutions.

## 🎯 Features

- Smart contract-based payment automation
- Driver token incentives
- NFT route tagging
- Reliability scoring system
- Real-time delivery tracking

## 🔧 Contract Functions

### For Drivers
- `register-driver`: Register as a new driver
- `accept-shipment`: Accept a pending shipment
- `complete-delivery`: Mark delivery as completed

### For Users
- `create-shipment`: Create a new shipment request
- `submit-review`: Rate completed deliveries

### Read-Only Functions
- `get-driver-stats`: View driver statistics
- `get-shipment`: Get shipment details
- `get-route-nft`: View route NFT information

## 🚀 Getting Started

1. Install Clarinet
2. Clone the repository
3. Run `clarinet console` to interact with the contract
4. Use the contract functions to create shipments and manage deliveries

## 💡 Usage Example

```clarity
;; Register as a driver
(contract-call? .decentralized-microport-logistics-protocol register-driver)

;; Create a shipment
(contract-call? .decentralized-microport-logistics-protocol create-shipment 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
  u1000 
  "QmHash...")
```

## 🤝 Contributing

Feel free to submit issues and enhancement requests!
```

Git commit message:
```
feat: implement decentralized microport logistics MVP with core shipping functionality
```

PR Title:
```
✨ MVP: Decentralized Microport Logistics Protocol
```

PR Description:
```
This PR introduces the Minimum Viable Product for the Decentralized Microport Logistics Protocol.

Key additions:
- Core smart contract implementation
- Driver registration and management
- Shipment creation and tracking
- Route NFT system
- Review and reliability scoring
- Token reward mechanism

The implementation focuses on essential features while maintaining clean, minimal code structure. Ready for initial testing and feedback.


## 🔄 Recent Enhancements

### Dynamic Driver Reliability Scoring
- **Automatic Updates**: Driver reliability scores now update automatically based on review ratings upon submission.
- **Aggregated Ratings**: Scores calculated as the average of all received ratings, ensuring fair representation of performance.
- **Enhanced Trust**: Improves platform transparency by reflecting real-time driver reputation from user feedback.
