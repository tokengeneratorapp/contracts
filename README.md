[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com/tokengeneratorapp/contracts/blob/main/LICENSE)
[![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.20-363636?logo=solidity)](https://soliditylang.org/)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-v5-4E5EE4?logo=openzeppelin)](https://docs.openzeppelin.com/contracts/5.x/)
[![Website](https://img.shields.io/badge/Website-tokengeneratorapp.com-6366f1)](https://tokengeneratorapp.com)
[![X (Twitter)](https://img.shields.io/badge/Follow-@tokengenerate-000000?logo=x)](https://x.com/tokengenerate)

# TokenGeneratorApp — Verified Smart Contracts

Open-source ERC-20 & BEP-20 token contracts used by [TokenGeneratorApp](https://tokengeneratorapp.com). Built on [OpenZeppelin v5](https://docs.openzeppelin.com/contracts/5.x/).

> **Create your own token in minutes** — No coding required. Deploy verified tokens on 7+ blockchains from your own wallet.
>
> 👉 **[Launch App →](https://tokengeneratorapp.com/create)**

## Contracts

| Contract | Features | Package |
| --- | --- | --- |
| **BasicToken** | Fixed supply, ownership, renounce | Basic |
| **StandardToken** | + Burn, Mint, Pause, Blacklist | Standard |
| **PremiumToken** | + Buy/Sell tax, Anti-whale, Max tx/wallet | Premium |

## Security

* **OpenZeppelin v5** — The most audited smart contract library in the industry
* **No proxy patterns** — Contracts are immutable after deployment
* **No hidden mint** — All functions are clearly documented
* **Hard-coded tax cap** — Premium contracts enforce a 25% maximum tax
* **Auto-verified** — Every deployment is verified on block explorers (BscScan, Etherscan, etc.)
* **Non-custodial** — Users deploy from their own wallet; we never control funds

🔒 [Read our full Security Policy →](https://tokengeneratorapp.com/security)

## Supported Networks

| Network | Explorer | Deploy Fee |
| --- | --- | --- |
| BNB Chain | [BscScan](https://bscscan.com) | 0.05 BNB |
| Ethereum | [Etherscan](https://etherscan.io) | 0.008 ETH |
| Base | [BaseScan](https://basescan.org) | 0.008 ETH |
| Polygon | [PolygonScan](https://polygonscan.com) | 35 POL |
| Arbitrum | [Arbiscan](https://arbiscan.io) | 0.008 ETH |
| Avalanche | [Snowtrace](https://snowtrace.io) | 1.5 AVAX |
| Optimism | [Etherscan (OP)](https://optimistic.etherscan.io) | 0.008 ETH |

📊 [View all networks & pricing →](https://tokengeneratorapp.com/pricing)

## How It Works

1. Connect your wallet on [tokengeneratorapp.com/create](https://tokengeneratorapp.com/create)
2. Configure token settings (name, symbol, supply, features)
3. Sign the deployment transaction — the contract is deployed directly from your wallet
4. Contract is automatically verified on the block explorer

We **never** have access to user wallets, tokens, or funds. The deployment transaction goes directly from the user's wallet to the blockchain.

📖 [Step-by-step guide →](https://tokengeneratorapp.com/how-it-works)

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

* Buy tax: 0–2500 (0–25%)
* Sell tax: 0–2500 (0–25%)
* Hard-coded `MAX_TAX = 2500` cannot be overridden

**Anti-whale limits:**

* Max wallet: 1–100% of total supply
* Max transaction: 1–100% of total supply
* Limits can be permanently removed via `removeLimits()`

## Verified Deployments

| Network | Contract | Address |
| --- | --- | --- |
| BSC Testnet | BasicToken | [`0xd17C8d645eD0C99b00af41C22A9d5F96Ca6C54f9`](https://testnet.bscscan.com/address/0xd17C8d645eD0C99b00af41C22A9d5F96Ca6C54f9) |

## License

MIT — see [LICENSE](LICENSE) for details.

## Links

**🚀 App**
* [Create Token](https://tokengeneratorapp.com/create) — Launch the token creator
* [Pricing](https://tokengeneratorapp.com/pricing) — Network fees & packages
* [How It Works](https://tokengeneratorapp.com/how-it-works) — Step-by-step guide
* [Networks](https://tokengeneratorapp.com/networks) — Supported blockchains
* [Roadmap](https://tokengeneratorapp.com/roadmap) — Upcoming features

**📚 Guides**
* [BEP-20 Token Generator](https://tokengeneratorapp.com/bep20-token-generator) — Create BNB Chain tokens
* [ERC-20 Token Generator](https://tokengeneratorapp.com/erc20-token-generator) — Create Ethereum tokens
* [Create BNB Token](https://tokengeneratorapp.com/create-bnb-token) — BNB Chain deployment guide
* [Create ERC-20 Token](https://tokengeneratorapp.com/create-erc20-token) — Ethereum deployment guide
* [Verify BEP-20 Contract](https://tokengeneratorapp.com/verify-bep20-contract) — Contract verification guide
* [Verify ERC-20 Contract](https://tokengeneratorapp.com/verify-erc20-contract) — Contract verification guide

**📖 Resources**
* [Blog](https://tokengeneratorapp.com/blog) — Tutorials, guides & Web3 insights
* [FAQ](https://tokengeneratorapp.com/faq) — Frequently asked questions
* [Security](https://tokengeneratorapp.com/security) — Our security practices
* [Contact](https://tokengeneratorapp.com/contact) — Get in touch

**🌐 Social**
* [X (Twitter)](https://x.com/tokengenerate) — @tokengenerate
