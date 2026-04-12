// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title BasicToken
/// @notice Fixed-supply ERC-20 token for the Basic package.
contract BasicToken is ERC20, Ownable {
    error InvalidOwner();
    error InvalidSupply();
    error InvalidDecimals();
    error FeeTransferFailed();

    uint8 private immutable _customDecimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        address owner_,
        address feeReceiver_
    ) payable ERC20(name_, symbol_) Ownable(owner_) {
        if (owner_ == address(0)) revert InvalidOwner();
        if (totalSupply_ == 0) revert InvalidSupply();
        if (decimals_ > 18) revert InvalidDecimals();

        _customDecimals = decimals_;
        _mint(owner_, totalSupply_ * 10 ** decimals_);
        _forwardFee(feeReceiver_);
    }

    function decimals() public view override returns (uint8) {
        return _customDecimals;
    }

    function generator() external pure returns (string memory) {
        return "https://tokengeneratorapp.com";
    }

    function _forwardFee(address feeReceiver_) private {
        if (msg.value == 0 || feeReceiver_ == address(0)) return;

        (bool ok,) = payable(feeReceiver_).call{value: msg.value}("");
        if (!ok) revert FeeTransferFailed();
    }
}
