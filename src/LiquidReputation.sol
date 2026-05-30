// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title LiquidReputation
/// @notice Per-agent staking pool. Users deposit mETH to back an agent's future
///         performance and receive proportional shares. If the agent breaches the
///         weekly drawdown threshold, the oracle slashes the pool (transfers a
///         portion to treasury). Share-to-mETH ratio reflects the live pool state.
///
/// @dev Simple share-based accounting:
///        shares = amount * totalShares / totalStaked   (subsequent stakes)
///        shares = amount                                (bootstrap)
///        mETHOut = shareAmount * totalStaked / totalShares
contract LiquidReputation {
    using SafeERC20 for IERC20;

    // ─── Storage ──────────────────────────────────────────────────────────
    IERC20 public immutable mETH;
    address public owner;
    address public oracle;
    address public treasury;

    /// @dev max single-event slash, basis points (5000 = 50%)
    uint16 public constant MAX_SLASH_BPS = 5000;

    struct Pool {
        uint256 totalStaked; // mETH currently in pool
        uint256 totalShares;
    }

    mapping(uint256 agentId => Pool) public pools;
    mapping(uint256 agentId => mapping(address user => uint256 shares)) public balances;

    // ─── Events ───────────────────────────────────────────────────────────
    event Staked(uint256 indexed agentId, address indexed user, uint256 amount, uint256 sharesMinted);
    event Unstaked(uint256 indexed agentId, address indexed user, uint256 sharesBurned, uint256 amount);
    event Slashed(uint256 indexed agentId, uint256 slashBps, uint256 amount);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    // ─── Modifiers ────────────────────────────────────────────────────────
    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle, "not oracle");
        _;
    }

    // ─── Constructor ──────────────────────────────────────────────────────
    constructor(address _mETH, address _oracle, address _treasury) {
        require(_mETH != address(0) && _oracle != address(0) && _treasury != address(0), "zero addr");
        owner = msg.sender;
        mETH = IERC20(_mETH);
        oracle = _oracle;
        treasury = _treasury;
    }

    // ─── User API ─────────────────────────────────────────────────────────

    /// @notice Stake mETH into an agent's reputation pool.
    function stake(uint256 agentId, uint256 amount) external {
        require(amount > 0, "zero amount");
        Pool storage p = pools[agentId];

        uint256 newShares;
        if (p.totalShares == 0) {
            newShares = amount;
        } else {
            newShares = (amount * p.totalShares) / p.totalStaked;
        }
        require(newShares > 0, "shares = 0");

        balances[agentId][msg.sender] += newShares;
        p.totalStaked += amount;
        p.totalShares += newShares;

        mETH.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(agentId, msg.sender, amount, newShares);
    }

    /// @notice Burn shares to redeem mETH at current ratio.
    function unstake(uint256 agentId, uint256 shareAmount) external {
        require(shareAmount > 0, "zero shares");
        require(balances[agentId][msg.sender] >= shareAmount, "insufficient shares");

        Pool storage p = pools[agentId];
        uint256 amountOut = (shareAmount * p.totalStaked) / p.totalShares;

        balances[agentId][msg.sender] -= shareAmount;
        p.totalStaked -= amountOut;
        p.totalShares -= shareAmount;

        mETH.safeTransfer(msg.sender, amountOut);
        emit Unstaked(agentId, msg.sender, shareAmount, amountOut);
    }

    // ─── Oracle API ───────────────────────────────────────────────────────

    /// @notice Slash a portion of an agent's pool to treasury.
    function slash(uint256 agentId, uint16 slashBps) external onlyOracle {
        require(slashBps > 0 && slashBps <= MAX_SLASH_BPS, "bad slashBps");
        Pool storage p = pools[agentId];
        require(p.totalStaked > 0, "empty pool");

        uint256 slashAmount = (p.totalStaked * slashBps) / 10_000;
        p.totalStaked -= slashAmount;

        mETH.safeTransfer(treasury, slashAmount);
        emit Slashed(agentId, slashBps, slashAmount);
    }

    // ─── Read API ─────────────────────────────────────────────────────────

    /// @notice Get the mETH-equivalent value of a user's shares for an agent.
    function previewUnstake(uint256 agentId, address user) external view returns (uint256) {
        Pool memory p = pools[agentId];
        if (p.totalShares == 0) return 0;
        return (balances[agentId][user] * p.totalStaked) / p.totalShares;
    }

    // ─── Admin ────────────────────────────────────────────────────────────
    function setOracle(address newOracle) external onlyOwner {
        require(newOracle != address(0), "zero addr");
        emit OracleUpdated(oracle, newOracle);
        oracle = newOracle;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "zero addr");
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }
}
