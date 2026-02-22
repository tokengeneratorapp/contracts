// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BasicToken
 * @dev Simple ERC-20 / BEP-20 token with configurable name, symbol, decimals, and supply.
 * Built on OpenZeppelin v5. Deployed via https://tokengeneratorapp.com
 *
 * Features:
 * - Fixed supply (minted once at deployment)
 * - Ownership (transferable, renounceable)
 * - No hidden mint, no backdoors, no proxy
 * - Auto-verified on block explorers
 */
contract BasicToken is ERC20, Ownable {
    uint8 private immutable _decimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        address owner_,
        address feeReceiver_
    ) payable ERC20(name_, symbol_) Ownable(owner_) {
        require(owner_ != address(0), "Owner cannot be zero address");
        require(totalSupply_ > 0, "Supply must be > 0");
        require(decimals_ <= 18, "Decimals must be <= 18");

        _decimals = decimals_;
        _mint(owner_, totalSupply_ * 10 ** decimals_);

        // Transfer deployment fee to fee receiver
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
}
