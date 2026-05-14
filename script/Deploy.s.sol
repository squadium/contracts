// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {SortinoOracle} from "../src/SortinoOracle.sol";
import {Squadium} from "../src/Squadium.sol";
import {LiquidReputation} from "../src/LiquidReputation.sol";
import {RewardDistributor} from "../src/RewardDistributor.sol";
import {MockMETH} from "../src/mocks/MockMETH.sol";

/// @notice Deploy script for Squadium contracts.
///         Required env:
///           DEPLOYER_PRIVATE_KEY      - deployer EOA
///           ORACLE_SIGNER_ADDRESS     - off-chain indexer signer (optional, falls
///                                       back to deployer if unset)
///           METH_ADDRESS              - canonical mETH on mainnet (optional, falls
///                                       back to deploying a MockMETH on testnet)
///           TREASURY_ADDRESS          - treasury recipient for slashes (optional)
contract Deploy is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPk);

        address oracleSigner = vm.envOr("ORACLE_SIGNER_ADDRESS", deployer);
        address treasury = vm.envOr("TREASURY_ADDRESS", deployer);
        address mETHAddr = vm.envOr("METH_ADDRESS", address(0));

        console.log("Deployer:", deployer);
        console.log("Oracle signer:", oracleSigner);
        console.log("Treasury:", treasury);

        vm.startBroadcast(deployerPk);

        // 1. mETH — use canonical address on mainnet, otherwise deploy a mock
        address mETH = mETHAddr;
        if (mETH == address(0)) {
            MockMETH mock = new MockMETH();
            mETH = address(mock);
            console.log("MockMETH:", mETH);
        } else {
            console.log("Using existing mETH:", mETH);
        }

        // 2. Core registry — oracleSigner is the off-chain indexer address that pushes tiers
        AgentRegistry registry = new AgentRegistry(oracleSigner);
        console.log("AgentRegistry:", address(registry));

        // 3. SortinoOracle — same signer (single trusted indexer in v1)
        SortinoOracle sortino = new SortinoOracle(oracleSigner);
        console.log("SortinoOracle:", address(sortino));

        // 4. Squadium game contract
        Squadium squadium = new Squadium(address(registry), oracleSigner);
        console.log("Squadium:", address(squadium));

        // 5. LiquidReputation pool
        LiquidReputation liquidRep = new LiquidReputation(mETH, oracleSigner, treasury);
        console.log("LiquidReputation:", address(liquidRep));

        // 6. RewardDistributor
        RewardDistributor rewards = new RewardDistributor(mETH, oracleSigner);
        console.log("RewardDistributor:", address(rewards));

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("mETH                 :", mETH);
        console.log("AgentRegistry        :", address(registry));
        console.log("SortinoOracle        :", address(sortino));
        console.log("Squadium             :", address(squadium));
        console.log("LiquidReputation     :", address(liquidRep));
        console.log("RewardDistributor    :", address(rewards));
    }
}
