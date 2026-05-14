// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {RewardDistributor} from "../src/RewardDistributor.sol";
import {MockMETH} from "../src/mocks/MockMETH.sol";

contract RewardDistributorTest is Test {
    RewardDistributor rd;
    MockMETH mETH;

    address oracle = address(0xA1);
    address alice = address(0xB1);
    address bob = address(0xB2);

    function setUp() public {
        mETH = new MockMETH();
        rd = new RewardDistributor(address(mETH), oracle);
        mETH.mint(address(rd), 1000 ether); // pre-fund
    }

    function _distributeTo(address user, uint256 amount, uint256 weekId) internal {
        address[] memory users = new address[](1);
        users[0] = user;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        vm.prank(oracle);
        rd.distribute(weekId, users, amounts);
    }

    function test_distribute_createsGrant() public {
        _distributeTo(alice, 10 ether, 1);
        assertEq(rd.grantCount(alice), 1);
    }

    function test_distribute_revertsForNonOracle() public {
        address[] memory users = new address[](1);
        users[0] = alice;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10 ether;

        vm.prank(alice);
        vm.expectRevert("not oracle");
        rd.distribute(1, users, amounts);
    }

    function test_claim_revertsBeforeCliff() public {
        _distributeTo(alice, 10 ether, 1);
        vm.prank(alice);
        vm.expectRevert("cliff not reached");
        rd.claim(0);
    }

    function test_claim_partialAfterCliff() public {
        _distributeTo(alice, 30 ether, 1);

        // Jump to halfway through vesting (cliff + half of vest window)
        // cliffEnd = start + 7d, vestEnd = start + 30d → window = 23d
        vm.warp(block.timestamp + 7 days + 11.5 days);

        vm.prank(alice);
        rd.claim(0);

        // ~50% of 30 ether = ~15 ether (allow small rounding tolerance)
        uint256 received = mETH.balanceOf(alice);
        assertGt(received, 14.5 ether);
        assertLt(received, 15.5 ether);
    }

    function test_claim_fullAfterVestEnd() public {
        _distributeTo(alice, 30 ether, 1);

        vm.warp(block.timestamp + 31 days);
        vm.prank(alice);
        rd.claim(0);
        assertEq(mETH.balanceOf(alice), 30 ether);
    }

    function test_claim_revertsOnZeroClaimable() public {
        _distributeTo(alice, 30 ether, 1);
        vm.warp(block.timestamp + 31 days);
        vm.prank(alice);
        rd.claim(0);

        // Second claim should fail — nothing left
        vm.prank(alice);
        vm.expectRevert("nothing to claim");
        rd.claim(0);
    }

    function test_claimAll_aggregatesAcrossGrants() public {
        _distributeTo(alice, 10 ether, 1);
        _distributeTo(alice, 20 ether, 2);

        vm.warp(block.timestamp + 31 days);
        vm.prank(alice);
        rd.claimAll();
        assertEq(mETH.balanceOf(alice), 30 ether);
    }

    function test_claimable_view() public {
        _distributeTo(alice, 30 ether, 1);

        assertEq(rd.claimable(alice, 0), 0); // before cliff
        vm.warp(block.timestamp + 31 days);
        assertEq(rd.claimable(alice, 0), 30 ether);
    }

    function test_distribute_revertsOnLengthMismatch() public {
        address[] memory users = new address[](2);
        users[0] = alice;
        users[1] = bob;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        vm.prank(oracle);
        vm.expectRevert("bad length");
        rd.distribute(1, users, amounts);
    }
}
