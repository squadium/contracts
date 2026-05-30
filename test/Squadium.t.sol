// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {Squadium} from "../src/Squadium.sol";

contract SquadiumTest is Test {
    AgentRegistry registry;
    Squadium squadium;

    address registryOracle = address(0xA1);
    address gameOracle = address(0xA2);
    address alice = address(0xB1);

    function setUp() public {
        registry = new AgentRegistry(registryOracle);
        squadium = new Squadium(address(registry), gameOracle);

        // Register 6 agents and assign tiers so we have a draftable pool
        for (uint256 i = 1; i <= 6; i++) {
            registry.registerAgent(i, address(uint160(0x1000 + i)), i);
        }
        vm.startPrank(registryOracle);
        registry.updateAgent(1, AgentRegistry.Tier.Legendary, 25_000, 0, false); // 35
        registry.updateAgent(2, AgentRegistry.Tier.Elite, 18_000, 0, false); // 25
        registry.updateAgent(3, AgentRegistry.Tier.Pro, 12_000, 0, false); // 18
        registry.updateAgent(4, AgentRegistry.Tier.Rising, 8000, 0, false); // 12
        registry.updateAgent(5, AgentRegistry.Tier.Rookie, 0, 0, false); // 8
        registry.updateAgent(6, AgentRegistry.Tier.Rookie, 0, 0, false); // 8
        vm.stopPrank();
    }

    function test_draftSquad_underCap() public {
        uint256[5] memory ids = [uint256(1), 2, 3, 5, 6]; // 35+25+18+8+8 = 94 ≤ 100
        vm.prank(alice);
        squadium.draftSquad(ids, 0, Squadium.Chip.None);

        // Spot check via tuple destructuring on the mapping getter.
        // Public getter skips the `uint256[5] agentIds` array, returns 5 fields.
        (uint8 captainIdx, Squadium.Chip chip, bool locked, bool settled,) = squadium.squads(1, alice);
        assertEq(captainIdx, 0);
        assertEq(uint8(chip), uint8(Squadium.Chip.None));
        assertFalse(locked);
        assertFalse(settled);
    }

    function test_draftSquad_revertsAboveCap() public {
        uint256[5] memory ids = [uint256(1), 1, 1, 1, 1]; // 35*5 = 175 > 100
        // Duplicate agents allowed by contract; cost just exceeds cap.
        vm.prank(alice);
        vm.expectRevert("salary cap exceeded");
        squadium.draftSquad(ids, 0, Squadium.Chip.None);
    }

    function test_draftSquad_wildcardBypassesCap() public {
        uint256[5] memory ids = [uint256(1), 1, 1, 1, 1]; // way over cap
        vm.prank(alice);
        squadium.draftSquad(ids, 0, Squadium.Chip.Wildcard);
        assertTrue(squadium.chipsUsed(alice, Squadium.Chip.Wildcard));
    }

    function test_draftSquad_revertsOnBadCaptain() public {
        uint256[5] memory ids = [uint256(1), 2, 3, 5, 6];
        vm.prank(alice);
        vm.expectRevert("bad captain");
        squadium.draftSquad(ids, 5, Squadium.Chip.None);
    }

    function test_chip_cannotBeReusedSameSeason() public {
        uint256[5] memory ids = [uint256(5), 5, 5, 5, 5]; // 40 credits, under cap
        vm.startPrank(alice);
        squadium.draftSquad(ids, 0, Squadium.Chip.TripleCaptain);
        vm.stopPrank();

        // Advance week
        vm.prank(gameOracle);
        squadium.advanceWeek();

        // Reuse same chip
        vm.prank(alice);
        vm.expectRevert("chip already used");
        squadium.draftSquad(ids, 0, Squadium.Chip.TripleCaptain);
    }

    function test_lockWeek_byOracle() public {
        uint256[5] memory ids = [uint256(5), 5, 5, 5, 5];
        vm.prank(alice);
        squadium.draftSquad(ids, 0, Squadium.Chip.None);

        vm.prank(gameOracle);
        squadium.lockWeek(1, alice);

        (,, bool locked,,) = squadium.squads(1, alice);
        assertTrue(locked);
    }

    function test_settleSquad_byOracle() public {
        uint256[5] memory ids = [uint256(5), 5, 5, 5, 5];
        vm.prank(alice);
        squadium.draftSquad(ids, 0, Squadium.Chip.None);

        vm.startPrank(gameOracle);
        squadium.lockWeek(1, alice);
        squadium.settleSquad(1, alice, 58_700);
        vm.stopPrank();

        (,,, bool settled, int256 score) = squadium.squads(1, alice);
        assertTrue(settled);
        assertEq(score, 58_700);
    }

    function test_advanceWeek_revertsForNonOracle() public {
        vm.prank(alice);
        vm.expectRevert("not oracle");
        squadium.advanceWeek();
    }
}
