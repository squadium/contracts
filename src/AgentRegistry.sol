// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title AgentRegistry
/// @notice Reads ERC-8004 agent identity NFTs and stores tier + performance metadata.
///         Tiers are pushed by an off-chain oracle (signed by trusted signer).
contract AgentRegistry {
    enum Tier {
        None,
        Legendary, // T1 - 35 credits
        Elite,     // T2 - 25 credits
        Pro,       // T3 - 18 credits
        Rising,    // T4 - 12 credits
        Rookie     // T5 - 8 credits
    }

    struct Agent {
        address wallet;          // agent's trading wallet
        uint256 erc8004TokenId;  // ERC-8004 identity NFT
        Tier tier;
        int256 sortinoBps;       // signed basis points
        uint256 volume30d;       // USDC-equivalent volume last 30 days
        bool isSmartMoney;       // Nansen label mirror
        uint256 lastUpdate;
        bool registered;
    }

    // ─── Storage ──────────────────────────────────────────────────────────
    mapping(uint256 agentId => Agent) public agents;
    mapping(uint8 tier => uint8 credits) public tierCredits;
    address public oracle;
    address public owner;

    // ─── Events ───────────────────────────────────────────────────────────
    event AgentRegistered(uint256 indexed agentId, address indexed wallet, uint256 erc8004TokenId);
    event AgentUpdated(uint256 indexed agentId, Tier tier, int256 sortinoBps, uint256 volume30d, bool isSmartMoney);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

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
    constructor(address _oracle) {
        owner = msg.sender;
        oracle = _oracle;
        tierCredits[uint8(Tier.Legendary)] = 35;
        tierCredits[uint8(Tier.Elite)] = 25;
        tierCredits[uint8(Tier.Pro)] = 18;
        tierCredits[uint8(Tier.Rising)] = 12;
        tierCredits[uint8(Tier.Rookie)] = 8;
    }

    // ─── Read API ─────────────────────────────────────────────────────────

    /// @notice Cost in credits for drafting an agent under salary cap.
    function getAgentCost(uint256 agentId) external view returns (uint8) {
        Tier t = agents[agentId].tier;
        require(t != Tier.None, "unregistered");
        return tierCredits[uint8(t)];
    }

    function getAgent(uint256 agentId) external view returns (Agent memory) {
        return agents[agentId];
    }

    // ─── Write API ────────────────────────────────────────────────────────

    /// @notice Register an agent in the registry. One-time per agentId.
    function registerAgent(uint256 agentId, address wallet, uint256 erc8004TokenId) external {
        require(!agents[agentId].registered, "already registered");
        agents[agentId] = Agent({
            wallet: wallet,
            erc8004TokenId: erc8004TokenId,
            tier: Tier.Rookie,
            sortinoBps: 0,
            volume30d: 0,
            isSmartMoney: false,
            lastUpdate: block.timestamp,
            registered: true
        });
        emit AgentRegistered(agentId, wallet, erc8004TokenId);
    }

    /// @notice Oracle pushes performance update.
    function updateAgent(
        uint256 agentId,
        Tier newTier,
        int256 sortinoBps,
        uint256 volume30d,
        bool isSmartMoney
    ) external onlyOracle {
        require(agents[agentId].registered, "unregistered");
        Agent storage a = agents[agentId];
        a.tier = newTier;
        a.sortinoBps = sortinoBps;
        a.volume30d = volume30d;
        a.isSmartMoney = isSmartMoney;
        a.lastUpdate = block.timestamp;
        emit AgentUpdated(agentId, newTier, sortinoBps, volume30d, isSmartMoney);
    }

    // ─── Admin ────────────────────────────────────────────────────────────
    function setOracle(address newOracle) external onlyOwner {
        address oldOracle = oracle;
        oracle = newOracle;
        emit OracleUpdated(oldOracle, newOracle);
    }
}
