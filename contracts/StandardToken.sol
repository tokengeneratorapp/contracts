// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title StandardToken
/// @notice Optional burn, mint, pause, and blacklist ERC-20 token.
contract StandardToken is ERC20, ERC20Pausable, Ownable {
    error InvalidOwner();
    error InvalidSupply();
    error InvalidDecimals();
    error FeatureDisabled();
    error CannotBlacklistOwner();
    error BlacklistedAccount();
    error FeeTransferFailed();

    uint8 private immutable _customDecimals;
    uint8 private immutable _features;

    mapping(address account => bool) private _blacklisted;

    uint8 private constant FEATURE_BURN = 1 << 0;
    uint8 private constant FEATURE_MINT = 1 << 1;
    uint8 private constant FEATURE_PAUSE = 1 << 2;
    uint8 private constant FEATURE_BLACKLIST = 1 << 3;

    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);

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
    ) payable ERC20(name_, symbol_) Ownable(owner_) {
        if (owner_ == address(0)) revert InvalidOwner();
        if (totalSupply_ == 0) revert InvalidSupply();
        if (decimals_ > 18) revert InvalidDecimals();

        _customDecimals = decimals_;
        _features = _packFeatures(burnEnabled_, mintEnabled_, pauseEnabled_, blacklistEnabled_);

        _mint(owner_, totalSupply_ * 10 ** decimals_);
        _forwardFee(feeReceiver_);
    }

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

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        if (blacklistEnabled() && (_blacklisted[from] || _blacklisted[to])) {
            revert BlacklistedAccount();
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
