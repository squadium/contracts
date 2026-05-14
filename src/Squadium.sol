// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AgentRegistry} from "./AgentRegistry.sol";

/// @title Squadium
/// @notice Core game contract: weekly draft, lock, settlement, claim.
///         A user picks 5 agents under a 100-credit salary cap. One captain
///         (2x scoring weight). Optional chips per season.
contract Squadium {
    // ─── Constants ────────────────────────────────────────────────────────
    uint8 public constant SQUAD_SIZE = 5;
    uint8 public constant SALARY_CAP = 100;

    enum Chip {
        None,
        Wildcard,
        TripleCaptain,
        BenchBoost,
        FreeHit
    }

    struct Squad {
        uint256[5] agentIds;
        uint8 captainIdx;
        Chip activeChip;
        bool locked;
        bool settled;
        int256 finalScore;
    }

    // ─── Storage ──────────────────────────────────────────────────────────
    AgentRegistry public immutable registry;
    address public owner;
    address public oracle; // off-chain settles weekly

    /// @dev squads[weekId][user] = squad
    mapping(uint256 weekId => mapping(address user => Squad)) public squads;

    /// @dev chipsUsed[user][chip] — once per season per chip
    mapping(address user => mapping(Chip chip => bool)) public chipsUsed;

    /// @dev current week pointer (advances on settle)
    uint256 public currentWeekId;

    // ─── Events ───────────────────────────────────────────────────────────
    event SquadDrafted(address indexed user, uint256 indexed weekId, uint256[5] agentIds, uint8 captainIdx, Chip chip);
    event WeekSettled(uint256 indexed weekId, uint256 settledCount);
    event SquadScored(address indexed user, uint256 indexed weekId, int256 score);

    // ─── Modifiers ────────────────────────────────────────────────────────
    modifier onlyOracle() {
        require(msg.sender == oracle, "not oracle");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    // ─── Constructor ──────────────────────────────────────────────────────
    constructor(address _registry, address _oracle) {
        owner = msg.sender;
        registry = AgentRegistry(_registry);
        oracle = _oracle;
        currentWeekId = 1;
    }

    // ─── Draft API ────────────────────────────────────────────────────────
    function draftSquad(uint256[5] calldata agentIds, uint8 captainIdx, Chip chip) external {
        require(captainIdx < SQUAD_SIZE, "bad captain");
        Squad storage s = squads[currentWeekId][msg.sender];
        require(!s.locked, "locked");

        // Validate salary cap (skip if Wildcard chip = bypass cap)
        if (chip != Chip.Wildcard) {
            uint16 totalCost;
            for (uint8 i = 0; i < SQUAD_SIZE; i++) {
                totalCost += registry.getAgentCost(agentIds[i]);
            }
            require(totalCost <= SALARY_CAP, "salary cap exceeded");
        }

        // Validate chip availability (one-time per season)
        if (chip != Chip.None) {
            require(!chipsUsed[msg.sender][chip], "chip already used");
            chipsUsed[msg.sender][chip] = true;
        }

        s.agentIds = agentIds;
        s.captainIdx = captainIdx;
        s.activeChip = chip;

        emit SquadDrafted(msg.sender, currentWeekId, agentIds, captainIdx, chip);
    }

    // ─── Settlement API (oracle) ──────────────────────────────────────────
    function settleSquad(uint256 weekId, address user, int256 finalScore) external onlyOracle {
        Squad storage s = squads[weekId][user];
        require(s.locked && !s.settled, "not lockable");
        s.settled = true;
        s.finalScore = finalScore;
        emit SquadScored(user, weekId, finalScore);
    }

    function advanceWeek() external onlyOracle {
        emit WeekSettled(currentWeekId, 0); // off-chain logs count
        currentWeekId += 1;
    }

    function lockWeek(uint256 weekId, address user) external onlyOracle {
        Squad storage s = squads[weekId][user];
        require(!s.locked, "already locked");
        s.locked = true;
    }

    // ─── Admin ────────────────────────────────────────────────────────────
    function setOracle(address newOracle) external onlyOwner {
        oracle = newOracle;
    }
}
