// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title PremiumToken
/// @notice ERC-20 token with optional management features, tax collection, manual tax withdrawal, and limits.
/// @dev No auto-liquidity. No router integration. Collected tax remains in this contract until manualSwap().
contract PremiumToken is ERC20, ERC20Pausable, Ownable {
    using SafeERC20 for IERC20;

    error InvalidOwner();
    error InvalidSupply();
    error InvalidDecimals();
    error InvalidTax();
    error InvalidLimit();
    error InvalidAddress();
    error FeatureDisabled();
    error CannotBlacklistOwner();
    error BlacklistedAccount();
    error MaxTxExceeded();
    error MaxWalletExceeded();
    error NothingToWithdraw();
    error FeeTransferFailed();

    uint256 public constant MAX_TAX = 2_500; // 25% in basis points
    uint256 private constant BPS = 10_000;

    uint8 private immutable _customDecimals;
    uint8 private immutable _features;

    uint256 public buyTax;
    uint256 public sellTax;
    address public taxReceiver;

    uint256 public maxWalletAmount;
    uint256 public maxTxAmount;
    bool public limitsEnabled = true;

    mapping(address account => bool) private _blacklisted;
    mapping(address account => bool) public isTaxExempt;
    mapping(address account => bool) public isLimitExempt;
    mapping(address account => bool) public automatedMarketMakers;

    uint8 private constant FEATURE_BURN = 1 << 0;
    uint8 private constant FEATURE_MINT = 1 << 1;
    uint8 private constant FEATURE_PAUSE = 1 << 2;
    uint8 private constant FEATURE_BLACKLIST = 1 << 3;

    event TaxUpdated(uint256 buyTax, uint256 sellTax);
    event TaxReceiverUpdated(address indexed receiver);
    event TaxExemptUpdated(address indexed account, bool exempt);
    event LimitExemptUpdated(address indexed account, bool exempt);
    event LimitsUpdated(uint256 maxWalletAmount, uint256 maxTxAmount);
    event LimitsRemoved();
    event AMMUpdated(address indexed account, bool enabled);
    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);
    event TaxCollected(address indexed from, address indexed to, uint256 amount);
    event TaxWithdrawn(address indexed receiver, uint256 amount);

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        address owner_,
        address feeReceiver_,
        bool[5] memory features_, // [burn, mint, pause, blacklist, reserved]
        uint256[4] memory params_ // [buyTaxBps, sellTaxBps, maxWallet%, maxTx%]
    ) payable ERC20(name_, symbol_) Ownable(owner_) {
        if (owner_ == address(0)) revert InvalidOwner();
        if (totalSupply_ == 0) revert InvalidSupply();
        if (decimals_ > 18) revert InvalidDecimals();
        if (params_[0] > MAX_TAX || params_[1] > MAX_TAX) revert InvalidTax();
        if (params_[2] > 100 || params_[3] > 100) revert InvalidLimit();
        if (params_[2] != 0 && params_[2] < 1) revert InvalidLimit();
        if (params_[3] != 0 && params_[3] < 1) revert InvalidLimit();

        _customDecimals = decimals_;
        _features = _packFeatures(features_[0], features_[1], features_[2], features_[3]);

        buyTax = params_[0];
        sellTax = params_[1];
        taxReceiver = feeReceiver_ == address(0) ? owner_ : feeReceiver_;

        uint256 supply = totalSupply_ * 10 ** decimals_;
        _mint(owner_, supply);

        maxWalletAmount = params_[2] == 0 ? supply : (supply * params_[2]) / 100;
        maxTxAmount = params_[3] == 0 ? supply : (supply * params_[3]) / 100;

        isTaxExempt[owner_] = true;
        isTaxExempt[address(this)] = true;
        isLimitExempt[owner_] = true;
        isLimitExempt[address(this)] = true;
        isLimitExempt[taxReceiver] = true;

        _forwardFee(feeReceiver_);
    }

    receive() external payable {}

    function decimals() public view override returns (uint8) {
        return _customDecimals;
    }

    function generator() external pure returns (string memory) {
        return "https://tokengeneratorapp.com";
    }

    function burnEnabled() public view returns (bool) {
        return _hasFeature(FEATURE_BURN);
    }

    function mintEnabled() public view returns (bool) {
        return _hasFeature(FEATURE_MINT);
    }

    function pauseEnabled() public view returns (bool) {
        return _hasFeature(FEATURE_PAUSE);
    }

    function blacklistEnabled() public view returns (bool) {
        return _hasFeature(FEATURE_BLACKLIST);
    }

    function autoLiquidityEnabled() external pure returns (bool) {
        return false;
    }

    function burn(uint256 amount) external {
        if (!burnEnabled()) revert FeatureDisabled();
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external {
        if (!burnEnabled()) revert FeatureDisabled();
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        if (!mintEnabled()) revert FeatureDisabled();
        _mint(to, amount);
    }

    function pause() external onlyOwner {
        if (!pauseEnabled()) revert FeatureDisabled();
        _pause();
    }

    function unpause() external onlyOwner {
        if (!pauseEnabled()) revert FeatureDisabled();
        _unpause();
    }

    function blacklist(address account) external onlyOwner {
        if (!blacklistEnabled()) revert FeatureDisabled();
        if (account == owner()) revert CannotBlacklistOwner();

        _blacklisted[account] = true;
        emit Blacklisted(account);
    }

    function unblacklist(address account) external onlyOwner {
        if (!blacklistEnabled()) revert FeatureDisabled();

        _blacklisted[account] = false;
        emit Unblacklisted(account);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _blacklisted[account];
    }

    function setTax(uint256 buyTax_, uint256 sellTax_) external onlyOwner {
        if (buyTax_ > MAX_TAX || sellTax_ > MAX_TAX) revert InvalidTax();

        buyTax = buyTax_;
        sellTax = sellTax_;
        emit TaxUpdated(buyTax_, sellTax_);
    }

    function setTaxReceiver(address receiver) external onlyOwner {
        if (receiver == address(0)) revert InvalidAddress();

        taxReceiver = receiver;
        isLimitExempt[receiver] = true;
        emit TaxReceiverUpdated(receiver);
    }

    function setExemptFromTax(address account, bool exempt) external onlyOwner {
        isTaxExempt[account] = exempt;
        emit TaxExemptUpdated(account, exempt);
    }

    function isExemptFromTax(address account) external view returns (bool) {
        return isTaxExempt[account];
    }

    function setExemptFromLimits(address account, bool exempt) external onlyOwner {
        isLimitExempt[account] = exempt;
        emit LimitExemptUpdated(account, exempt);
    }

    function setAutomatedMarketMaker(address account, bool enabled) external onlyOwner {
        if (account == address(0)) revert InvalidAddress();

        automatedMarketMakers[account] = enabled;
        isLimitExempt[account] = enabled;
        emit AMMUpdated(account, enabled);
    }

    function setLimits(uint256 maxWalletAmount_, uint256 maxTxAmount_) external onlyOwner {
        uint256 supply = totalSupply();
        if (maxWalletAmount_ < supply / 100 || maxTxAmount_ < supply / 1_000) revert InvalidLimit();

        maxWalletAmount = maxWalletAmount_;
        maxTxAmount = maxTxAmount_;
        emit LimitsUpdated(maxWalletAmount_, maxTxAmount_);
    }

    function removeLimits() external onlyOwner {
        limitsEnabled = false;
        emit LimitsRemoved();
    }

    /// @notice Transfers collected tax tokens to the tax receiver.
    /// @dev Kept as manualSwap for backward UI/ABI compatibility. This is not DEX auto-liquidity.
    function manualSwap() external onlyOwner {
        uint256 amount = balanceOf(address(this));
        if (amount == 0) revert NothingToWithdraw();

        _update(address(this), taxReceiver, amount);
        emit TaxWithdrawn(taxReceiver, amount);
    }

    function withdrawStuckETH() external onlyOwner {
        uint256 amount = address(this).balance;
        if (amount == 0) revert NothingToWithdraw();

        (bool ok,) = payable(owner()).call{value: amount}("");
        if (!ok) revert FeeTransferFailed();
    }

    function withdrawStuckTokens(address token) external onlyOwner {
        if (token == address(this) || token == address(0)) revert InvalidAddress();

        uint256 amount = IERC20(token).balanceOf(address(this));
        if (amount == 0) revert NothingToWithdraw();

        IERC20(token).safeTransfer(owner(), amount);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        if (blacklistEnabled() && (_blacklisted[from] || _blacklisted[to])) {
            revert BlacklistedAccount();
        }

        if (from == address(0) || to == address(0) || from == address(this)) {
            super._update(from, to, value);
            return;
        }

        bool isBuy = automatedMarketMakers[from];
        bool isSell = automatedMarketMakers[to];

        if (limitsEnabled && !isLimitExempt[from] && !isLimitExempt[to]) {
            if ((isBuy || isSell) && value > maxTxAmount) revert MaxTxExceeded();
            if (!isSell && balanceOf(to) + value > maxWalletAmount) revert MaxWalletExceeded();
        }

        uint256 taxAmount;
        if (!isTaxExempt[from] && !isTaxExempt[to]) {
            uint256 tax = isBuy ? buyTax : isSell ? sellTax : 0;
            if (tax != 0) taxAmount = (value * tax) / BPS;
        }

        if (taxAmount != 0) {
            unchecked {
                value -= taxAmount;
            }
            super._update(from, address(this), taxAmount);
            emit TaxCollected(from, to, taxAmount);
        }

        super._update(from, to, value);
    }

    function _hasFeature(uint8 feature) private view returns (bool) {
        return _features & feature != 0;
    }

    function _packFeatures(
        bool burnEnabled_,
        bool mintEnabled_,
        bool pauseEnabled_,
        bool blacklistEnabled_
    ) private pure returns (uint8 features) {
        if (burnEnabled_) features |= FEATURE_BURN;
        if (mintEnabled_) features |= FEATURE_MINT;
        if (pauseEnabled_) features |= FEATURE_PAUSE;
        if (blacklistEnabled_) features |= FEATURE_BLACKLIST;
    }

    function _forwardFee(address feeReceiver_) private {
        if (msg.value == 0 || feeReceiver_ == address(0)) return;

        (bool ok,) = payable(feeReceiver_).call{value: msg.value}("");
        if (!ok) revert FeeTransferFailed();
    }
}
