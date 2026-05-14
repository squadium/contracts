// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title RewardDistributor
/// @notice Distributes weekly mETH rewards to top-ranked Squadium players.
///         Each grant has a cliff (no claim until cliffEnd) then linearly vests
///         until vestingEnd. Users can hold multiple grants in parallel.
contract RewardDistributor {
    using SafeERC20 for IERC20;

    // ─── Storage ──────────────────────────────────────────────────────────
    IERC20 public immutable mETH;
    address public owner;
    address public oracle;

    /// @dev cliff and vesting durations are immutable v1 — can be replaced in v2.
    uint64 public constant CLIFF_DURATION = 7 days;
    uint64 public constant VEST_DURATION = 30 days;

    struct Grant {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint64 startTime;
        uint64 cliffEnd;
        uint64 vestEnd;
        uint256 weekId;
    }

    mapping(address user => Grant[]) public grants;

    // ─── Events ───────────────────────────────────────────────────────────
    event RewardDistributed(uint256 indexed weekId, address indexed user, uint256 amount, uint256 grantIdx);
    event RewardClaimed(address indexed user, uint256 grantIdx, uint256 amount);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

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
    constructor(address _mETH, address _oracle) {
        require(_mETH != address(0) && _oracle != address(0), "zero addr");
        owner = msg.sender;
        mETH = IERC20(_mETH);
        oracle = _oracle;
    }

    // ─── Oracle API ───────────────────────────────────────────────────────

    /// @notice Distribute rewards to winners for a given week.
    ///         Caller (oracle) must have pre-funded the contract with at least
    ///         the sum of amounts. Each (user, amount) pair becomes a new vesting
    ///         grant with a 7-day cliff and 30-day linear vest.
    function distribute(uint256 weekId, address[] calldata users, uint256[] calldata amounts) external onlyOracle {
        require(users.length == amounts.length && users.length > 0, "bad length");

        uint64 start = uint64(block.timestamp);
        uint64 cliff = start + CLIFF_DURATION;
        uint64 vestEnd = start + VEST_DURATION;

        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "zero user");
            require(amounts[i] > 0, "zero amount");
            grants[users[i]].push(
                Grant({
                    totalAmount: amounts[i],
                    claimedAmount: 0,
                    startTime: start,
                    cliffEnd: cliff,
                    vestEnd: vestEnd,
                    weekId: weekId
                })
            );
            emit RewardDistributed(weekId, users[i], amounts[i], grants[users[i]].length - 1);
        }
    }

    // ─── User API ─────────────────────────────────────────────────────────

    /// @notice Claim all vested-but-unclaimed mETH from a specific grant.
    function claim(uint256 grantIdx) external {
        Grant storage g = grants[msg.sender][grantIdx];
        require(g.totalAmount > 0, "no grant");
        require(block.timestamp >= g.cliffEnd, "cliff not reached");

        uint256 vested = _vestedAmount(g);
        uint256 claimable = vested - g.claimedAmount;
        require(claimable > 0, "nothing to claim");

        g.claimedAmount += claimable;
        mETH.safeTransfer(msg.sender, claimable);
        emit RewardClaimed(msg.sender, grantIdx, claimable);
    }

    /// @notice Convenience batch claim across all grants.
    function claimAll() external {
        uint256 total;
        Grant[] storage userGrants = grants[msg.sender];
        for (uint256 i = 0; i < userGrants.length; i++) {
            Grant storage g = userGrants[i];
            if (g.totalAmount == 0 || block.timestamp < g.cliffEnd) continue;
            uint256 vested = _vestedAmount(g);
            uint256 claimable = vested - g.claimedAmount;
            if (claimable == 0) continue;
            g.claimedAmount += claimable;
            total += claimable;
            emit RewardClaimed(msg.sender, i, claimable);
        }
        require(total > 0, "nothing to claim");
        mETH.safeTransfer(msg.sender, total);
    }

    // ─── Read API ─────────────────────────────────────────────────────────

    function grantCount(address user) external view returns (uint256) {
        return grants[user].length;
    }

    function claimable(address user, uint256 grantIdx) external view returns (uint256) {
        Grant memory g = grants[user][grantIdx];
        if (block.timestamp < g.cliffEnd) return 0;
        return _vestedAmount(g) - g.claimedAmount;
    }

    // ─── Internal ─────────────────────────────────────────────────────────

    function _vestedAmount(Grant memory g) internal view returns (uint256) {
        if (block.timestamp >= g.vestEnd) return g.totalAmount;
        if (block.timestamp < g.cliffEnd) return 0;
        // Linear from cliffEnd to vestEnd
        uint256 elapsed = block.timestamp - g.cliffEnd;
        uint256 totalWindow = g.vestEnd - g.cliffEnd;
        return (g.totalAmount * elapsed) / totalWindow;
    }

    // ─── Admin ────────────────────────────────────────────────────────────

    function setOracle(address newOracle) external onlyOwner {
        require(newOracle != address(0), "zero addr");
        emit OracleUpdated(oracle, newOracle);
        oracle = newOracle;
    }

    /// @notice Allow owner to rescue stuck ERC20 tokens. Cannot drain active grants —
    ///         use only for accidental airdrops of other tokens.
    function rescueToken(address token, uint256 amount) external onlyOwner {
        require(token != address(mETH), "use grants");
        IERC20(token).safeTransfer(owner, amount);
    }
}
