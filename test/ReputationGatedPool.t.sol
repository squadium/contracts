// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {AgentReputationOracle} from "../src/AgentReputationOracle.sol";
import {ReputationGatedPool} from "../src/ReputationGatedPool.sol";

contract ReputationGatedPoolTest is Test {
    AgentReputationOracle oracle;
    ReputationGatedPool pool;

    uint256 signerPk = 0xA11CE;
    address signer;
    uint64 constant MAX_STALE = 2 days;

    function setUp() public {
        signer = vm.addr(signerPk);
        oracle = new AgentReputationOracle(signer);
        pool = new ReputationGatedPool(address(oracle), MAX_STALE);
        // start at a sane timestamp so asOf math never underflows
        vm.warp(1_000_000);
    }

    function _push(uint256 agentId, uint16 score, uint16 conf, uint8 tier, uint64 asOf, uint256 nonce) internal {
        AgentReputationOracle.Reputation memory r = AgentReputationOracle.Reputation({
            score: score,
            confidence: conf,
            tier: tier,
            asOf: asOf,
            horizon: 7 days
        });
        bytes32 digest = keccak256(
            abi.encodePacked(agentId, r.score, r.confidence, r.tier, r.asOf, r.horizon, nonce, address(oracle))
        );
        bytes32 ethSigned = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 rr, bytes32 ss) = vm.sign(signerPk, ethSigned);
        oracle.pushReputation(agentId, r, nonce, abi.encodePacked(rr, ss, v));
    }

    function test_rate_scalesWithScore() public {
        _push(1, 0, 8000, 1, uint64(block.timestamp), 1); // score 0 → no discount
        assertEq(pool.borrowRateBps(1), 1_200);

        _push(2, 5_000, 8000, 1, uint64(block.timestamp), 1); // 50% → 400 off → 800
        assertEq(pool.borrowRateBps(2), 800);

        _push(3, 10_000, 8000, 1, uint64(block.timestamp), 1); // max → 800 off → 400
        assertEq(pool.borrowRateBps(3), 400);
    }

    function test_eligible_trueForGoodAgent() public {
        _push(1, 7000, 7000, 2, uint64(block.timestamp), 1);
        assertTrue(pool.eligible(1));
    }

    function test_revert_notRated() public {
        vm.expectRevert(abi.encodeWithSelector(ReputationGatedPool.NotRated.selector, uint256(99)));
        pool.borrowRateBps(99);
        assertFalse(pool.eligible(99));
    }

    function test_revert_tierTooLow() public {
        _push(1, 9000, 9000, 4, uint64(block.timestamp), 1); // tier 4 > MIN_TIER(3)
        vm.expectRevert(abi.encodeWithSelector(ReputationGatedPool.TierTooLow.selector, uint8(4)));
        pool.borrowRateBps(1);
        assertFalse(pool.eligible(1));
    }

    function test_revert_confidenceTooLow() public {
        _push(1, 9000, 5999, 1, uint64(block.timestamp), 1); // conf < 6000
        vm.expectRevert(abi.encodeWithSelector(ReputationGatedPool.ConfidenceTooLow.selector, uint16(5999)));
        pool.borrowRateBps(1);
        assertFalse(pool.eligible(1));
    }

    function test_revert_stale() public {
        uint64 staleAsOf = uint64(block.timestamp);
        _push(1, 9000, 9000, 1, staleAsOf, 1);
        // jump past maxStaleness
        vm.warp(block.timestamp + MAX_STALE + 1);
        vm.expectRevert(
            abi.encodeWithSelector(ReputationGatedPool.ReputationStale.selector, staleAsOf, uint64(block.timestamp))
        );
        pool.borrowRateBps(1);
        assertFalse(pool.eligible(1));
    }

    function test_eligible_boundaryConfidenceExactly6000() public {
        _push(1, 8000, 6000, 3, uint64(block.timestamp), 1); // conf == MIN, tier == MIN
        assertTrue(pool.eligible(1));
        assertEq(pool.borrowRateBps(1), 1_200 - uint16((uint256(8000) * 800) / 10_000));
    }

    function test_constructor_revertsOnZeroOracle() public {
        vm.expectRevert("zero oracle");
        new ReputationGatedPool(address(0), MAX_STALE);
    }

    function test_constructor_revertsOnZeroStaleness() public {
        vm.expectRevert("zero staleness");
        new ReputationGatedPool(address(oracle), 0);
    }
}
