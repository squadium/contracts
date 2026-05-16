// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {AgentReputationOracle} from "../src/AgentReputationOracle.sol";

contract AgentReputationOracleTest is Test {
    AgentReputationOracle oracle;
    uint256 signerPk = 0xA11CE;
    address signer;

    function setUp() public {
        signer = vm.addr(signerPk);
        oracle = new AgentReputationOracle(signer);
    }

    function _rep(uint16 score, uint16 conf, uint8 tier) internal view returns (AgentReputationOracle.Reputation memory) {
        return AgentReputationOracle.Reputation({
            score: score,
            confidence: conf,
            tier: tier,
            asOf: uint64(block.timestamp),
            horizon: 7 days
        });
    }

    function _sign(uint256 agentId, AgentReputationOracle.Reputation memory r, uint256 nonce)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = keccak256(
            abi.encodePacked(agentId, r.score, r.confidence, r.tier, r.asOf, r.horizon, nonce, address(oracle))
        );
        bytes32 ethSigned = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 rr, bytes32 ss) = vm.sign(signerPk, ethSigned);
        return abi.encodePacked(rr, ss, v);
    }

    function test_pushReputation_valid() public {
        AgentReputationOracle.Reputation memory r = _rep(8200, 7500, 1);
        oracle.pushReputation(1, r, 1, _sign(1, r, 1));

        AgentReputationOracle.Reputation memory got = oracle.reputationOf(1);
        assertEq(got.score, 8200);
        assertEq(got.confidence, 7500);
        assertEq(got.tier, 1);
        assertEq(got.horizon, 7 days);
        assertTrue(oracle.isRated(1));
    }

    function test_backCompatShim_mirrorsScore() public {
        AgentReputationOracle.Reputation memory r = _rep(6400, 5000, 3);
        oracle.pushReputation(7, r, 1, _sign(7, r, 1));
        // indexer reads agentSortinoBps — must mirror the score
        assertEq(oracle.agentSortinoBps(7), int256(6400));
    }

    function test_pushReputation_revertsOnReplay() public {
        AgentReputationOracle.Reputation memory r = _rep(5000, 5000, 3);
        oracle.pushReputation(1, r, 1, _sign(1, r, 1));
        vm.expectRevert("bad nonce");
        oracle.pushReputation(1, r, 1, _sign(1, r, 1));
    }

    function test_pushReputation_revertsOnBadNonce() public {
        AgentReputationOracle.Reputation memory r = _rep(5000, 5000, 3);
        vm.expectRevert("bad nonce");
        oracle.pushReputation(1, r, 5, _sign(1, r, 5));
    }

    function test_pushReputation_revertsOnBadSigner() public {
        AgentReputationOracle.Reputation memory r = _rep(5000, 5000, 3);
        uint256 attackerPk = 0xBAD;
        bytes32 digest = keccak256(
            abi.encodePacked(uint256(1), r.score, r.confidence, r.tier, r.asOf, r.horizon, uint256(1), address(oracle))
        );
        bytes32 ethSigned = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 rr, bytes32 ss) = vm.sign(attackerPk, ethSigned);
        vm.expectRevert("bad signer");
        oracle.pushReputation(1, r, 1, abi.encodePacked(rr, ss, v));
    }

    function test_pushReputation_revertsOnBadTier() public {
        AgentReputationOracle.Reputation memory r = _rep(5000, 5000, 6); // tier > 5
        vm.expectRevert("bad tier");
        oracle.pushReputation(1, r, 1, _sign(1, r, 1));
    }

    function test_pushReputation_revertsOnOutOfRange() public {
        AgentReputationOracle.Reputation memory r = _rep(10_001, 5000, 3); // score > 10000
        vm.expectRevert("out of range");
        oracle.pushReputation(1, r, 1, _sign(1, r, 1));
    }

    function test_isRated_falseBeforePush() public view {
        assertFalse(oracle.isRated(999));
    }

    function test_nonce_incrementsSequentially() public {
        AgentReputationOracle.Reputation memory r1 = _rep(5000, 5000, 3);
        oracle.pushReputation(2, r1, 1, _sign(2, r1, 1));
        AgentReputationOracle.Reputation memory r2 = _rep(6000, 6000, 2);
        oracle.pushReputation(2, r2, 2, _sign(2, r2, 2));
        assertEq(oracle.nonces(2), 2);
        assertEq(oracle.reputationOf(2).score, 6000);
    }

    function test_setSigner_byOwner() public {
        oracle.setSigner(address(0xC1));
        assertEq(oracle.signer(), address(0xC1));
    }

    function test_setSigner_revertsForNonOwner() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert("not owner");
        oracle.setSigner(address(0xC1));
    }

    function test_setSigner_revertsOnZero() public {
        vm.expectRevert("zero signer");
        oracle.setSigner(address(0));
    }
}
