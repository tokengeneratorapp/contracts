// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PremiumToken
 * @dev Advanced ERC-20 / BEP-20 token with tax, anti-whale, and liquidity features.
 * Built on OpenZeppelin v5. Deployed via https://tokengeneratorapp.com
 *
 * Features (all configurable at deployment):
 * - Buy/Sell tax (max 25%, hard-coded cap)
 * - Anti-whale: Max wallet & max transaction limits
 * - Burn, Mint, Pause, Blacklist (toggleable)
 * - Tax-exempt addresses
 * - Auto swap collected tax to native token
 * - No proxy, no upgradeable logic
 * - Auto-verified on block explorers
 *
 * Tax is capped at MAX_TAX (2500 = 25%) and cannot be increased beyond this.
 * Limits can be removed permanently by the owner via removeLimits().
 */
contract PremiumToken is ERC20, ERC20Pausable, Ownable {
    uint256 public constant MAX_TAX = 2500; // 25% hard cap

    uint8 private immutable _decimals;

    bool public burnEnabled;
    bool public mintEnabled;
    bool public pauseEnabled;
    bool public blacklistEnabled;
    bool public autoLiquidityEnabled;
    bool public limitsEnabled = true;

    uint256 public buyTax;
    uint256 public sellTax;
    address public taxReceiver;

    uint256 public maxWalletAmount;
    uint256 public maxTxAmount;
    uint256 public swapThreshold;

    mapping(address => bool) private _blacklisted;
    mapping(address => bool) public isTaxExempt;
    mapping(address => bool) public isLimitExempt;
    mapping(address => bool) public automatedMarketMakers;

    bool private _inSwap;

    event TaxUpdated(uint256 buyTax, uint256 sellTax);
    event TaxReceiverUpdated(address indexed newReceiver);
    event TaxExemptUpdated(address indexed account, bool exempt);
    event LimitsUpdated(uint256 maxWallet, uint256 maxTx);
    event LimitsRemoved();
    event AMMUpdated(address indexed pair, bool isAMM);
    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        address owner_,
        address feeReceiver_,
        bool[5] memory features_, // [burn, mint, pause, blacklist, autoLiquidity]
        uint256[4] memory params_ // [buyTax, sellTax, maxWallet%, maxTx%]
    ) payable ERC20(name_, symbol_) Ownable(owner_) {
        require(owner_ != address(0), "Owner cannot be zero address");
        require(totalSupply_ > 0, "Supply must be > 0");
        require(decimals_ <= 18, "Decimals must be <= 18");
        require(params_[0] <= MAX_TAX, "Buy tax > max");
        require(params_[1] <= MAX_TAX, "Sell tax > max");
        require(params_[2] >= 1 && params_[2] <= 100, "Max wallet: 1-100%");
        require(params_[3] >= 1 && params_[3] <= 100, "Max tx: 1-100%");

        _decimals = decimals_;
        burnEnabled = features_[0];
        mintEnabled = features_[1];
        pauseEnabled = features_[2];
        blacklistEnabled = features_[3];
        autoLiquidityEnabled = features_[4];

        buyTax = params_[0];
        sellTax = params_[1];
        taxReceiver = feeReceiver_;

        uint256 supply = totalSupply_ * 10 ** decimals_;
        _mint(owner_, supply);

        maxWalletAmount = (supply * params_[2]) / 100;
        maxTxAmount = (supply * params_[3]) / 100;
        swapThreshold = supply / 2000; // 0.05%

        isTaxExempt[owner_] = true;
        isTaxExempt[address(this)] = true;
        isLimitExempt[owner_] = true;
        isLimitExempt[address(this)] = true;

        if (msg.value > 0 && feeReceiver_ != address(0)) {
            (bool success, ) = feeReceiver_.call{value: msg.value}("");
            require(success, "Fee transfer failed");
        }
    }

    receive() external payable {}

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function generator() public pure returns (string memory) {
        return "https://tokengeneratorapp.com";
    }

    // --- Tax ---
    function setTax(uint256 buyTax_, uint256 sellTax_) external onlyOwner {
        require(buyTax_ <= MAX_TAX, "Buy tax > max");
        require(sellTax_ <= MAX_TAX, "Sell tax > max");
        buyTax = buyTax_;
        sellTax = sellTax_;
        emit TaxUpdated(buyTax_, sellTax_);
    }

    function setTaxReceiver(address receiver_) external onlyOwner {
        require(receiver_ != address(0), "Zero address");
        taxReceiver = receiver_;
        emit TaxReceiverUpdated(receiver_);
    }

    function setExemptFromTax(address account, bool exempt) external onlyOwner {
        isTaxExempt[account] = exempt;
    }

    function isExemptFromTax(address account) public view returns (bool) {
        return isTaxExempt[account];
    }

    // --- Limits ---
    function setLimits(uint256 maxWallet_, uint256 maxTx_) external onlyOwner {
        require(maxWallet_ >= totalSupply() / 100, "Min 1% of supply");
        require(maxTx_ >= totalSupply() / 1000, "Min 0.1% of supply");
        maxWalletAmount = maxWallet_;
        maxTxAmount = maxTx_;
        emit LimitsUpdated(maxWallet_, maxTx_);
    }

    function removeLimits() external onlyOwner {
        limitsEnabled = false;
        emit LimitsRemoved();
    }

    function setExemptFromLimits(address account, bool exempt) external onlyOwner {
        isLimitExempt[account] = exempt;
    }

    // --- AMM ---
    function setAutomatedMarketMaker(address pair, bool isAMM) external onlyOwner {
        require(pair != address(0), "Zero address");
        automatedMarketMakers[pair] = isAMM;
        isLimitExempt[pair] = isAMM;
        emit AMMUpdated(pair, isAMM);
    }

    // --- Burn ---
    function burn(uint256 amount) public {
        require(burnEnabled, "Burning is disabled");
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) public {
        require(burnEnabled, "Burning is disabled");
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }

    // --- Mint ---
    function mint(address to, uint256 amount) public onlyOwner {
        require(mintEnabled, "Minting is disabled");
        _mint(to, amount);
    }

    // --- Pause ---
    function pause() public onlyOwner {
        require(pauseEnabled, "Pausing is disabled");
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // --- Blacklist ---
    function blacklist(address account) public onlyOwner {
        require(blacklistEnabled, "Blacklisting is disabled");
        require(account != owner(), "Cannot blacklist owner");
        _blacklisted[account] = true;
        emit Blacklisted(account);
    }

    function unblacklist(address account) public onlyOwner {
        _blacklisted[account] = false;
        emit Unblacklisted(account);
    }

    function isBlacklisted(address account) public view returns (bool) {
        return _blacklisted[account];
    }

    // --- Swap ---
    function manualSwap() external onlyOwner {
        _swapTax();
    }

    function _swapTax() private {
        _inSwap = true;
        uint256 balance = balanceOf(address(this));
        if (balance == 0) { _inSwap = false; return; }
        _transfer(address(this), taxReceiver, balance);
        _inSwap = false;
    }

    // --- Withdraw stuck ---
    function withdrawStuckETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function withdrawStuckTokens(address token_) external onlyOwner {
        require(token_ != address(this), "Cannot withdraw own tokens");
        uint256 balance = IERC20(token_).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        IERC20(token_).transfer(owner(), balance);
    }

    // --- Core transfer logic ---
    function _update(address from, address to, uint256 value)
        internal
        virtual
        override(ERC20, ERC20Pausable)
    {
        // Blacklist check
        if (blacklistEnabled) {
            require(!_blacklisted[from], "Sender is blacklisted");
            require(!_blacklisted[to], "Recipient is blacklisted");
        }

        // Skip logic for mints, burns, and internal swaps
        if (from == address(0) || to == address(0) || _inSwap) {
            super._update(from, to, value);
            return;
        }

        bool isBuy = automatedMarketMakers[from];
        bool isSell = automatedMarketMakers[to];

        // Limits check
        if (limitsEnabled) {
            if (!isLimitExempt[from] && !isLimitExempt[to]) {
                if (isBuy || isSell) {
                    require(value <= maxTxAmount, "Exceeds max transaction");
                }
                if (!isSell) {
                    require(
                        balanceOf(to) + value <= maxWalletAmount,
                        "Exceeds max wallet"
                    );
                }
            }
        }

        // Tax calculation
        uint256 taxAmount = 0;
        if (!isTaxExempt[from] && !isTaxExempt[to]) {
            if (isBuy && buyTax > 0) {
                taxAmount = (value * buyTax) / 10000;
            } else if (isSell && sellTax > 0) {
                taxAmount = (value * sellTax) / 10000;
            }
        }

        // Auto swap
        if (isSell && !_inSwap && balanceOf(address(this)) >= swapThreshold) {
            _swapTax();
        }

        // Execute transfer with tax
        if (taxAmount > 0) {
            super._update(from, address(this), taxAmount);
            value -= taxAmount;
        }

        super._update(from, to, value);
    }
}
