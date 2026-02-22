// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StandardToken
 * @dev ERC-20 / BEP-20 token with optional burn, mint, pause, and blacklist features.
 * Built on OpenZeppelin v5. Deployed via https://tokengeneratorapp.com
 *
 * Features (toggleable at deployment):
 * - Burn: Token holders can burn their own tokens
 * - Mint: Owner can mint new tokens (renounceable)
 * - Pause: Owner can pause all transfers (renounceable)
 * - Blacklist: Owner can blacklist addresses (renounceable)
 * - No hidden functions, no proxy, no upgradeable logic
 * - Auto-verified on block explorers
 */
contract StandardToken is ERC20, ERC20Pausable, Ownable {
    uint8 private immutable _decimals;

    bool public burnEnabled;
    bool public mintEnabled;
    bool public pauseEnabled;
    bool public blacklistEnabled;

    mapping(address => bool) private _blacklisted;

    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);
    event FeatureToggled(string feature, bool enabled);

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
        require(owner_ != address(0), "Owner cannot be zero address");
        require(totalSupply_ > 0, "Supply must be > 0");
        require(decimals_ <= 18, "Decimals must be <= 18");

        _decimals = decimals_;
        burnEnabled = burnEnabled_;
        mintEnabled = mintEnabled_;
        pauseEnabled = pauseEnabled_;
        blacklistEnabled = blacklistEnabled_;

        _mint(owner_, totalSupply_ * 10 ** decimals_);

        if (msg.value > 0 && feeReceiver_ != address(0)) {
            (bool success, ) = feeReceiver_.call{value: msg.value}("");
            require(success, "Fee transfer failed");
        }
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function generator() public pure returns (string memory) {
        return "https://tokengeneratorapp.com";
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

    // --- Overrides ---
    function _update(address from, address to, uint256 value)
        internal
        virtual
        override(ERC20, ERC20Pausable)
    {
        if (blacklistEnabled) {
            require(!_blacklisted[from], "Sender is blacklisted");
            require(!_blacklisted[to], "Recipient is blacklisted");
        }
        super._update(from, to, value);
    }
}
