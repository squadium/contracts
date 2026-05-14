// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";

contract AgentRegistryTest is Test {
    AgentRegistry registry;
    address oracle = address(0xA1);
    address owner = address(this);
    address alice = address(0xB1);

    function setUp() public {
        registry = new AgentRegistry(oracle);
    }

    function test_constructor_setsTierCredits() public view {
        assertEq(registry.tierCredits(uint8(AgentRegistry.Tier.Legendary)), 35);
        assertEq(registry.tierCredits(uint8(AgentRegistry.Tier.Elite)), 25);
        assertEq(registry.tierCredits(uint8(AgentRegistry.Tier.Pro)), 18);
        assertEq(registry.tierCredits(uint8(AgentRegistry.Tier.Rising)), 12);
        assertEq(registry.tierCredits(uint8(AgentRegistry.Tier.Rookie)), 8);
    }

    function test_registerAgent_defaultsToRookie() public {
        registry.registerAgent(1, alice, 42);
        AgentRegistry.Agent memory a = registry.getAgent(1);
        assertEq(a.wallet, alice);
        assertEq(a.erc8004TokenId, 42);
        assertEq(uint8(a.tier), uint8(AgentRegistry.Tier.Rookie));
        assertTrue(a.registered);
    }

    function test_registerAgent_revertsOnDouble() public {
        registry.registerAgent(1, alice, 42);
        vm.expectRevert("already registered");
        registry.registerAgent(1, alice, 42);
    }

    function test_getAgentCost_revertsForUnregistered() public {
        vm.expectRevert("unregistered");
        registry.getAgentCost(999);
    }

    function test_updateAgent_byOracle() public {
        registry.registerAgent(1, alice, 42);

        vm.prank(oracle);
        registry.updateAgent(1, AgentRegistry.Tier.Legendary, 25_000, 1_000_000e6, true);

        AgentRegistry.Agent memory a = registry.getAgent(1);
        assertEq(uint8(a.tier), uint8(AgentRegistry.Tier.Legendary));
        assertEq(a.sortinoBps, 25_000);
        assertEq(a.volume30d, 1_000_000e6);
        assertTrue(a.isSmartMoney);
        assertEq(registry.getAgentCost(1), 35);
    }

    function test_updateAgent_revertsForNonOracle() public {
        registry.registerAgent(1, alice, 42);
        vm.prank(alice);
        vm.expectRevert("not oracle");
        registry.updateAgent(1, AgentRegistry.Tier.Elite, 0, 0, false);
    }

    function test_setOracle_byOwner() public {
        address newOracle = address(0xC1);
        registry.setOracle(newOracle);
        assertEq(registry.oracle(), newOracle);
    }

    function test_setOracle_revertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert("not owner");
        registry.setOracle(address(0xC1));
    }
}
