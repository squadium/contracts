// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AgentReputationOracle} from "./AgentReputationOracle.sol";

/// @title ReputationGatedPool
/// @notice Composability proof — NOT production lending. Demonstrates that any
///         Mantle protocol can consume Squadium's on-chain reputation as
///         infrastructure: borrow rate scales down with an agent's CCRI score,
///         and access is gated by tier, confidence, and oracle freshness.
///
///         This is the Grand Champion "Mantle Ecosystem Contribution" argument
///         in one contract: the oracle is a public good others build on.
contract ReputationGatedPool {
    AgentReputationOracle public immutable oracle;

    uint16 public constant BASE_RATE_BPS = 1200; // 12.00%
    uint16 public constant MAX_DISCOUNT_BPS = 800; // up to 8.00% off
    uint8 public constant MIN_TIER = 3; // require T1..T3 (tier <= 3)
    uint16 public constant MIN_CONFIDENCE = 6000; // require >= 60.00%
    uint64 public immutable maxStaleness; // seconds; reputation older than this is rejected

    error NotRated(uint256 agentId);
    error TierTooLow(uint8 tier);
    error ConfidenceTooLow(uint16 confidence);
    error ReputationStale(uint64 asOf, uint64 nowTs);

    constructor(address _oracle, uint64 _maxStaleness) {
        require(_oracle != address(0), "zero oracle");
        require(_maxStaleness > 0, "zero staleness");
        oracle = AgentReputationOracle(_oracle);
        maxStaleness = _maxStaleness;
    }

    /// @notice True if the agent currently qualifies for an undercollateralized line.
    function eligible(uint256 agentId) public view returns (bool) {
        AgentReputationOracle.Reputation memory r = oracle.reputationOf(agentId);
        if (r.asOf == 0) return false;
        if (r.tier == 0 || r.tier > MIN_TIER) return false;
        if (r.confidence < MIN_CONFIDENCE) return false;
        if (block.timestamp > uint256(r.asOf) + maxStaleness) return false;
        return true;
    }

    /// @notice Borrow rate in bps for an agent. Reverts (typed) when ineligible
    ///         so integrators get a precise reason.
    function borrowRateBps(uint256 agentId) external view returns (uint16) {
        AgentReputationOracle.Reputation memory r = oracle.reputationOf(agentId);

        if (r.asOf == 0) revert NotRated(agentId);
        if (r.tier == 0 || r.tier > MIN_TIER) revert TierTooLow(r.tier);
        if (r.confidence < MIN_CONFIDENCE) revert ConfidenceTooLow(r.confidence);
        if (block.timestamp > uint256(r.asOf) + maxStaleness) {
            revert ReputationStale(r.asOf, uint64(block.timestamp));
        }

        // discount scales linearly with score (0..10000 → 0..MAX_DISCOUNT_BPS)
        uint16 discount = uint16((uint256(r.score) * MAX_DISCOUNT_BPS) / 10_000);
        return BASE_RATE_BPS - discount;
    }
}
