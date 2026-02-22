# TokenGeneratorApp — Verified Smart Contracts

Open-source ERC-20 & BEP-20 token contracts used by [TokenGeneratorApp](https://tokengeneratorapp.com). Built on [OpenZeppelin v5](https://docs.openzeppelin.com/contracts/5.x/).

## Contracts

| Contract | Features | Package |
|----------|----------|---------|
| **BasicToken** | Fixed supply, ownership, renounce | Basic |
| **StandardToken** | + Burn, Mint, Pause, Blacklist | Standard |
| **PremiumToken** | + Buy/Sell tax, Anti-whale, Max tx/wallet | Premium |

## Security

- **OpenZeppelin v5** — The most audited smart contract library in the industry
- **No proxy patterns** — Contracts are immutable after deployment
- **No hidden mint** — All functions are clearly documented
- **Hard-coded tax cap** — Premium contracts enforce a 25% maximum tax
- **Auto-verified** — Every deployment is verified on block explorers (BscScan, Etherscan, etc.)
- **Non-custodial** — Users deploy from their own wallet; we never control funds

## Supported Networks

| Network | Explorer | Deploy Fee |
|---------|----------|------------|
| BNB Chain | BscScan | 0.05 BNB |
| Ethereum | Etherscan | 0.008 ETH |
| Base | BaseScan | 0.008 ETH |
| Polygon | PolygonScan | 35 POL |
| Arbitrum | Arbiscan | 0.008 ETH |
| Avalanche | Snowtrace | 1.5 AVAX |
| Optimism | Etherscan (OP) | 0.008 ETH |

## How It Works

1. User connects their wallet on [tokengeneratorapp.com](https://tokengeneratorapp.com)
2. Configures token settings (name, symbol, supply, features)
3. Signs the deployment transaction — the contract is deployed directly from their wallet
4. Contract is automatically verified on the block explorer

We **never** have access to user wallets, tokens, or funds. The deployment transaction goes directly from the user's wallet to the blockchain.

## Contract Details

### BasicToken

Simple fixed-supply token. No additional features beyond standard ERC-20.

```solidity
constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    uint256 totalSupply_,
    address owner_,
    address feeReceiver_
)
```

### StandardToken

Extends BasicToken with optional burn, mint, pause, and blacklist. Each feature is enabled/disabled at deployment and cannot be changed afterward.

```solidity
constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    uint256 totalSupply_,
    address owner_,
    address feeReceiver_,
    bool burnEnabled_,
    bool mintEnabled_,
    bool pauseEnabled_,
    bool blacklistEnabled_
)
```

### PremiumToken

Full-featured token with tax system, anti-whale protections, and all Standard features.

```solidity
constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    uint256 totalSupply_,
    address owner_,
    address feeReceiver_,
    bool[5] memory features_,  // [burn, mint, pause, blacklist, autoLiquidity]
    uint256[4] memory params_  // [buyTax, sellTax, maxWallet%, maxTx%]
)
```

**Tax limits:**
- Buy tax: 0–2500 (0–25%)
- Sell tax: 0–2500 (0–25%)
- Hard-coded `MAX_TAX = 2500` cannot be overridden

**Anti-whale limits:**
- Max wallet: 1–100% of total supply
- Max transaction: 1–100% of total supply
- Limits can be permanently removed via `removeLimits()`

## Verified Deployments

| Network | Contract | Address |
|---------|----------|---------|
| BSC Testnet | BasicToken | [`0xd17C8d645eD0C99b00af41C22A9d5F96Ca6C54f9`](https://testnet.bscscan.com/address/0xd17C8d645eD0C99b00af41C22A9d5F96Ca6C54f9) |

## License

MIT — see [LICENSE](LICENSE) for details.

## Links

- 🌐 [tokengeneratorapp.com](https://tokengeneratorapp.com)
- 🔒 [Security](https://tokengeneratorapp.com/security)
- 📖 [Blog](https://tokengeneratorapp.com/blog)
- 📧 [Contact](https://tokengeneratorapp.com/contact)
