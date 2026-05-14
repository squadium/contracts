// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {LiquidReputation} from "../src/LiquidReputation.sol";
import {MockMETH} from "../src/mocks/MockMETH.sol";

contract LiquidReputationTest is Test {
    LiquidReputation lr;
    MockMETH mETH;

    address oracle = address(0xA1);
    address treasury = address(0xA2);
    address alice = address(0xB1);
    address bob = address(0xB2);

    uint256 constant AGENT_ID = 42;

    function setUp() public {
        mETH = new MockMETH();
        lr = new LiquidReputation(address(mETH), oracle, treasury);

        // Mint and approve for both users
        mETH.mint(alice, 100 ether);
        mETH.mint(bob, 100 ether);
        vm.prank(alice);
        mETH.approve(address(lr), type(uint256).max);
        vm.prank(bob);
        mETH.approve(address(lr), type(uint256).max);
    }

    function test_stake_bootstrapMintsOneToOne() public {
        vm.prank(alice);
        lr.stake(AGENT_ID, 10 ether);

        assertEq(lr.balances(AGENT_ID, alice), 10 ether);
        (uint256 totalStaked, uint256 totalShares) = lr.pools(AGENT_ID);
        assertEq(totalStaked, 10 ether);
        assertEq(totalShares, 10 ether);
    }

    function test_stake_subsequentUsesProRata() public {
        vm.prank(alice);
        lr.stake(AGENT_ID, 10 ether);

        // Bob stakes after — pool is still 1:1, so Bob also gets 5 shares for 5 mETH
        vm.prank(bob);
        lr.stake(AGENT_ID, 5 ether);
        assertEq(lr.balances(AGENT_ID, bob), 5 ether);
    }

    function test_unstake_returnsProRata() public {
        vm.prank(alice);
        lr.stake(AGENT_ID, 10 ether);

        uint256 before = mETH.balanceOf(alice);
        vm.prank(alice);
        lr.unstake(AGENT_ID, 10 ether);
        assertEq(mETH.balanceOf(alice) - before, 10 ether);
        assertEq(lr.balances(AGENT_ID, alice), 0);
    }

    function test_slash_reducesPool_byOracle() public {
        vm.prank(alice);
        lr.stake(AGENT_ID, 10 ether);

        vm.prank(oracle);
        lr.slash(AGENT_ID, 2_000); // 20%

        (uint256 totalStaked,) = lr.pools(AGENT_ID);
        assertEq(totalStaked, 8 ether);
        assertEq(mETH.balanceOf(treasury), 2 ether);
    }

    function test_slash_revertsAboveMax() public {
        vm.prank(alice);
        lr.stake(AGENT_ID, 10 ether);
        vm.prank(oracle);
        vm.expectRevert("bad slashBps");
        lr.slash(AGENT_ID, 6_000); // > 50%
    }

    function test_slash_revertsForNonOracle() public {
        vm.prank(alice);
        lr.stake(AGENT_ID, 10 ether);
        vm.prank(alice);
        vm.expectRevert("not oracle");
        lr.slash(AGENT_ID, 1_000);
    }

    function test_slash_thenUnstake_redeemsLessMETH() public {
        // Alice 10, Bob 10 → pool 20
        vm.prank(alice);
        lr.stake(AGENT_ID, 10 ether);
        vm.prank(bob);
        lr.stake(AGENT_ID, 10 ether);

        // 50% slash → pool now 10 mETH, shares still 20
        vm.prank(oracle);
        lr.slash(AGENT_ID, 5_000);

        // Alice burns her 10 shares → gets 5 mETH
        uint256 before = mETH.balanceOf(alice);
        vm.prank(alice);
        lr.unstake(AGENT_ID, 10 ether);
        assertEq(mETH.balanceOf(alice) - before, 5 ether);
    }

    function test_previewUnstake_returnsExpectedAmount() public {
        vm.prank(alice);
        lr.stake(AGENT_ID, 10 ether);
        assertEq(lr.previewUnstake(AGENT_ID, alice), 10 ether);

        vm.prank(oracle);
        lr.slash(AGENT_ID, 5_000);
        assertEq(lr.previewUnstake(AGENT_ID, alice), 5 ether);
    }

    function test_stake_revertsOnZero() public {
        vm.prank(alice);
        vm.expectRevert("zero amount");
        lr.stake(AGENT_ID, 0);
    }
}
