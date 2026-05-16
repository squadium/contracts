// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {AgentReputationOracle} from "../src/AgentReputationOracle.sol";
import {Squadium} from "../src/Squadium.sol";
import {LiquidReputation} from "../src/LiquidReputation.sol";
import {RewardDistributor} from "../src/RewardDistributor.sol";
import {ReputationGatedPool} from "../src/ReputationGatedPool.sol";
import {MockMETH} from "../src/mocks/MockMETH.sol";

/// @notice Deploy script for Squadium contracts (CCRI architecture).
///         Required env:
///           DEPLOYER_PRIVATE_KEY      - deployer EOA
///           ORACLE_SIGNER_ADDRESS     - off-chain CCRI service signer (optional,
///                                       falls back to deployer if unset)
///           METH_ADDRESS              - canonical mETH on mainnet (optional,
///                                       falls back to deploying a MockMETH)
///           TREASURY_ADDRESS          - treasury recipient for slashes (optional)
///           REPUTATION_MAX_STALENESS  - seconds before reputation is rejected by
///                                       consumers (optional, default 2 days)
contract Deploy is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPk);

        address oracleSigner = vm.envOr("ORACLE_SIGNER_ADDRESS", deployer);
        address treasury = vm.envOr("TREASURY_ADDRESS", deployer);
        address mETHAddr = vm.envOr("METH_ADDRESS", address(0));
        uint64 maxStaleness = uint64(vm.envOr("REPUTATION_MAX_STALENESS", uint256(2 days)));

        console.log("Deployer:", deployer);
        console.log("Oracle signer:", oracleSigner);
        console.log("Treasury:", treasury);

        vm.startBroadcast(deployerPk);

        // 1. mETH — canonical on mainnet, mock otherwise
        address mETH = mETHAddr;
        if (mETH == address(0)) {
            MockMETH mock = new MockMETH();
            mETH = address(mock);
            console.log("MockMETH:", mETH);
        } else {
            console.log("Using existing mETH:", mETH);
        }

        // 2. Core registry
        AgentRegistry registry = new AgentRegistry(oracleSigner);
        console.log("AgentRegistry:", address(registry));

        // 3. AgentReputationOracle — CCRI signed reputation feed (supersedes SortinoOracle)
        AgentReputationOracle reputation = new AgentReputationOracle(oracleSigner);
        console.log("AgentReputationOracle:", address(reputation));

        // 4. Squadium game (fantasy flywheel / calibration surface)
        Squadium squadium = new Squadium(address(registry), oracleSigner);
        console.log("Squadium:", address(squadium));

        // 5. LiquidReputation pool
        LiquidReputation liquidRep = new LiquidReputation(mETH, oracleSigner, treasury);
        console.log("LiquidReputation:", address(liquidRep));

        // 6. RewardDistributor
        RewardDistributor rewards = new RewardDistributor(mETH, oracleSigner);
        console.log("RewardDistributor:", address(rewards));

        // 7. ReputationGatedPool — composability proof: a Mantle dapp consuming the oracle
        ReputationGatedPool gatedPool = new ReputationGatedPool(address(reputation), maxStaleness);
        console.log("ReputationGatedPool:", address(gatedPool));

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("mETH                  :", mETH);
        console.log("AgentRegistry         :", address(registry));
        console.log("AgentReputationOracle :", address(reputation));
        console.log("Squadium              :", address(squadium));
        console.log("LiquidReputation      :", address(liquidRep));
        console.log("RewardDistributor     :", address(rewards));
        console.log("ReputationGatedPool   :", address(gatedPool));
    }
}
