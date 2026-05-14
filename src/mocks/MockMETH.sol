// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockMETH
/// @notice Test-only ERC20 token used to simulate mETH on Mantle Sepolia.
///         Open-mint via `mint()` so any address can self-fund.
///         NOT FOR MAINNET — real mETH on Mantle Mainnet is at the canonical address.
contract MockMETH is ERC20 {
    constructor() ERC20("Mock mETH", "mETH") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
