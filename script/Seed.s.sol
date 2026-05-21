// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";

/**
 * @notice Seed synthetic agents on Mantle Sepolia for demo / cold-start.
 *
 * The deployed `AgentRegistry.signer == deployer` (see Deploy.s.sol defaults),
 * so the deployer can both register AND assign tiers. This is the W6 cold-start
 * mitigation from CCRI spec §6: ship the dapp with REAL on-chain data instead
 * of vapor.
 *
 * Env:
 *   DEPLOYER_PRIVATE_KEY          deployer = registry oracle (defaults)
 *   AGENT_REGISTRY_ADDRESS_SEPOLIA  override (else uses live deployment)
 */
contract Seed is Script {
    AgentRegistry constant DEFAULT_REGISTRY = AgentRegistry(0x5C8061694C8c1b4A2aB39762754D9a0DC549fBB1);

    struct Seed_ {
        uint256 agentId;
        address wallet;
        uint256 tokenId;
        AgentRegistry.Tier tier;
        int256 sortinoBps;
        uint256 volume30d;
        bool isSmartMoney;
        string handle;
    }

    function run() external {
        uint256 pk = _readDeployerPk();
        address registryAddr = vm.envOr("AGENT_REGISTRY_ADDRESS_SEPOLIA", address(DEFAULT_REGISTRY));
        AgentRegistry registry = AgentRegistry(registryAddr);

        Seed_[10] memory seeds = _seeds();

        vm.startBroadcast(pk);
        for (uint256 i = 0; i < seeds.length; i++) {
            Seed_ memory s = seeds[i];
            try registry.registerAgent(s.agentId, s.wallet, s.tokenId) {
                console.log("registered", s.agentId, s.handle);
            } catch {
                console.log("skip (already registered)", s.agentId, s.handle);
            }
            registry.updateAgent(s.agentId, s.tier, s.sortinoBps, s.volume30d, s.isSmartMoney);
            console.log("  tier", uint256(uint8(s.tier)));
        }
        vm.stopBroadcast();
    }

    function _seeds() internal pure returns (Seed_[10] memory s) {
        s[0] = Seed_(42, 0x42aa000000000000000000000000000000001ce0, 1, AgentRegistry.Tier.Legendary, 28_400, 1_240_000e6, true, "MomentumMaxi");
        s[1] = Seed_(17, 0x17bB000000000000000000000000000000004F12, 2, AgentRegistry.Tier.Elite, 23_100, 880_000e6, false, "AlphaScout");
        s[2] = Seed_(88, 0x88cc000000000000000000000000000000007D33, 3, AgentRegistry.Tier.Elite, 20_500, 540_000e6, true, "VolatilityHunter");
        s[3] = Seed_(103, 0x103D000000000000000000000000000000009aAA, 4, AgentRegistry.Tier.Pro, 16_200, 310_000e6, false, "MeanReverter");
        s[4] = Seed_(145, 0x145E00000000000000000000000000000000B1c0, 5, AgentRegistry.Tier.Rising, 11_800, 180_000e6, false, "ArbiBot");
        s[5] = Seed_(211, 0x211f000000000000000000000000000000003789, 6, AgentRegistry.Tier.Rookie, 4_100, 28_000e6, false, "RookieClaw");
        s[6] = Seed_(64, 0x6440000000000000000000000000000000001234, 7, AgentRegistry.Tier.Pro, 17_400, 410_000e6, true, "RegimeRider");
        s[7] = Seed_(31, 0x3170000000000000000000000000000000005678, 8, AgentRegistry.Tier.Elite, 21_300, 720_000e6, false, "ClawSniper");
        s[8] = Seed_(7, 0x0700000000000000000000000000000000009aBc, 9, AgentRegistry.Tier.Rising, 9_400, 95_000e6, false, "GammaGoblin");
        s[9] = Seed_(255, 0xFf00000000000000000000000000000000000def, 10, AgentRegistry.Tier.Pro, 14_800, 220_000e6, false, "DeltaNeutralius");
    }

    /// @dev Accept DEPLOYER_PRIVATE_KEY with or without `0x` prefix.
    function _readDeployerPk() internal view returns (uint256) {
        string memory raw = vm.envString("DEPLOYER_PRIVATE_KEY");
        bytes memory rb = bytes(raw);
        bool hasPrefix = rb.length >= 2 && rb[0] == 0x30 && (rb[1] == 0x78 || rb[1] == 0x58);
        return vm.parseUint(hasPrefix ? raw : string.concat("0x", raw));
    }
}
