// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Squadium} from "../src/Squadium.sol";

/// @notice Seeds the crowd prior: 10 distinct manager wallets each draft a
///         squad in week 1. Stars (42/88/64) are drafted 5–6× so their
///         lifetimeAppearances climb → model + crowd confidence cross the 60%
///         consumer gate. Agent 31 is never drafted → stays gated (demo
///         contrast: drafting earns trust).
///
///         Manager wallets are derived deterministically and funded with gas
///         from the deployer in a single broadcast block, then each drafts.
///
///         Env: DEPLOYER_PRIVATE_KEY, SQUADIUM_ADDRESS (optional, defaults to
///         the 2026-05-19 Sepolia deployment).
contract SeedDrafts is Script {
    uint256 constant N = 10;
    uint256 constant GAS_FUND = 0.05 ether;

    function run() external {
        uint256 deployerPk = _readDeployerPk();
        address squadiumAddr =
            vm.envOr("SQUADIUM_ADDRESS", address(0x4299b716F33Be7F43D0Ebf0c1F4863D3fC4b37ec));
        Squadium squadium = Squadium(squadiumAddr);

        console.log("Squadium:", squadiumAddr);
        console.log("Funding + drafting from", N, "manager wallets");

        // 1. Fund all manager wallets for gas (single broadcast block)
        vm.startBroadcast(deployerPk);
        for (uint256 i = 0; i < N; i++) {
            address m = vm.addr(_managerPk(i));
            if (m.balance < GAS_FUND) {
                (bool ok,) = m.call{value: GAS_FUND}("");
                require(ok, "fund failed");
            }
        }
        vm.stopBroadcast();

        // 2. Each manager drafts a squad (≤100 credit cap respected)
        for (uint256 i = 0; i < N; i++) {
            (uint256[5] memory ids, uint8 captain, Squadium.Chip chip) = _squad(i);
            vm.broadcast(_managerPk(i));
            squadium.draftSquad(ids, captain, chip);
            console.log("manager", i, "drafted; captain idx", captain);
        }

        console.log("Seed drafts complete. Re-index, then re-run `pnpm ccri`.");
    }

    /// @dev Deterministic, namespaced manager keys (testnet-only demo wallets).
    function _managerPk(uint256 i) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked("squadium.manager.v1", i)));
    }

    /// @dev 10 hand-tuned squads. All ≤ 100 credits. Stars 42/88/64 recur.
    ///      Tier credits: 42=35 17/31/88=25 64/103/255=18 145/7=12 211=8
    function _squad(uint256 i) internal pure returns (uint256[5] memory ids, uint8 captain, Squadium.Chip chip) {
        if (i == 0) return ([uint256(42), 64, 145, 7, 211], 0, Squadium.Chip.None); // 85
        if (i == 1) return ([uint256(17), 88, 103, 145, 211], 0, Squadium.Chip.None); // 88
        if (i == 2) return ([uint256(42), 88, 255, 7, 211], 1, Squadium.Chip.TripleCaptain); // 98
        if (i == 3) return ([uint256(42), 17, 145, 7, 211], 0, Squadium.Chip.None); // 92
        if (i == 4) return ([uint256(88), 64, 103, 145, 211], 0, Squadium.Chip.BenchBoost); // 81
        if (i == 5) return ([uint256(42), 64, 255, 7, 211], 0, Squadium.Chip.None); // 91
        if (i == 6) return ([uint256(17), 64, 103, 7, 211], 0, Squadium.Chip.Wildcard); // 81
        if (i == 7) return ([uint256(42), 88, 145, 7, 211], 1, Squadium.Chip.None); // 92
        if (i == 8) return ([uint256(88), 64, 103, 7, 211], 0, Squadium.Chip.None); // 81
        return ([uint256(42), 17, 64, 7, 211], 0, Squadium.Chip.None); // 98
    }

    function _readDeployerPk() internal view returns (uint256) {
        string memory raw = vm.envString("DEPLOYER_PRIVATE_KEY");
        bytes memory rb = bytes(raw);
        bool hasPrefix = rb.length >= 2 && rb[0] == 0x30 && (rb[1] == 0x78 || rb[1] == 0x58);
        return vm.parseUint(hasPrefix ? raw : string.concat("0x", raw));
    }
}
