// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title AgentReputationOracle
/// @notice On-chain reputation feed for AI trading agents. The off-chain CCRI
///         service (Crowd-Calibrated Reputation Inference) computes a forward,
///         confidence-bounded reputation score and pushes it here with an
///         ECDSA-signed payload. Any Mantle protocol can read `reputationOf`.
///
///         Evolves SortinoOracle: same signer/nonce trust model, richer payload.
///         A backward-compat shim keeps `agentSortinoBps` + a `SortinoPushed`
///         event alive so the existing indexer/game pipeline needs zero rewrite.
contract AgentReputationOracle {
    struct Reputation {
        uint16 score; // 0..10000 forward risk-adjusted, re-normalized per cycle
        uint16 confidence; // 0..10000 (= 0.00%..100.00%)
        uint8 tier; // 1=T1 (best) .. 5=T5
        uint64 asOf; // inference timestamp
        uint64 horizon; // prediction horizon in seconds (e.g. 604800 = 7d)
    }

    address public signer;
    address public owner;

    mapping(uint256 agentId => uint256) public nonces;
    mapping(uint256 agentId => Reputation) private _rep;

    /// @dev Back-compat shim: indexer's SortinoOracle handler reads this mapping
    ///      + the SortinoPushed event. We mirror `score` here so the existing
    ///      pipeline keeps flowing without a rewrite. Not a true Sortino value —
    ///      it is the normalized forward score. Documented intentionally.
    mapping(uint256 agentId => int256) public agentSortinoBps;

    event ReputationPushed(
        uint256 indexed agentId, uint16 score, uint16 confidence, uint8 tier, uint64 asOf, uint64 horizon
    );
    // emitted for indexer back-compat (same shape as SortinoOracle.SortinoPushed)
    event SortinoPushed(uint256 indexed agentId, int256 sortinoBps, uint256 nonce, uint256 timestamp);
    event SignerUpdated(address indexed oldSigner, address indexed newSigner);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _signer) {
        require(_signer != address(0), "zero signer");
        owner = msg.sender;
        signer = _signer;
    }

    /// @notice Push a reputation update. Signature is over
    ///         (agentId, score, confidence, tier, asOf, horizon, nonce, address(this)).
    function pushReputation(uint256 agentId, Reputation calldata rep, uint256 nonce, bytes calldata sig) external {
        require(nonce == nonces[agentId] + 1, "bad nonce");
        require(rep.tier >= 1 && rep.tier <= 5, "bad tier");
        require(rep.score <= 10_000 && rep.confidence <= 10_000, "out of range");

        bytes32 digest = keccak256(
            abi.encodePacked(
                agentId, rep.score, rep.confidence, rep.tier, rep.asOf, rep.horizon, nonce, address(this)
            )
        );
        bytes32 ethSigned = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        require(_recover(ethSigned, sig) == signer, "bad signer");

        nonces[agentId] = nonce;
        _rep[agentId] = rep;

        // back-compat shim
        agentSortinoBps[agentId] = int256(uint256(rep.score));

        emit ReputationPushed(agentId, rep.score, rep.confidence, rep.tier, rep.asOf, rep.horizon);
        emit SortinoPushed(agentId, int256(uint256(rep.score)), nonce, block.timestamp);
    }

    // ─── Read API (consumed by Mantle protocols) ──────────────────────────

    function reputationOf(uint256 agentId) external view returns (Reputation memory) {
        return _rep[agentId];
    }

    /// @notice True if an agent has ever received a reputation push.
    function isRated(uint256 agentId) external view returns (bool) {
        return _rep[agentId].asOf != 0;
    }

    // ─── Admin ────────────────────────────────────────────────────────────

    function setSigner(address newSigner) external onlyOwner {
        require(newSigner != address(0), "zero signer");
        emit SignerUpdated(signer, newSigner);
        signer = newSigner;
    }

    // ─── Internal ─────────────────────────────────────────────────────────

    function _recover(bytes32 hash, bytes calldata sig) internal pure returns (address) {
        require(sig.length == 65, "bad sig length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        if (v < 27) v += 27;
        require(v == 27 || v == 28, "bad v");
        return ecrecover(hash, v, r, s);
    }
}
