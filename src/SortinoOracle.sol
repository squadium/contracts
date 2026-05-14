// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title SortinoOracle
/// @notice Accepts ECDSA-signed Sortino score updates from off-chain indexer.
///         Signer is the indexer key. Anyone can submit the signed payload —
///         the contract just verifies the signature.
contract SortinoOracle {
    address public signer;
    address public owner;

    /// @dev nonces prevent replay
    mapping(uint256 agentId => uint256) public nonces;

    /// @dev latest Sortino in bps (signed)
    mapping(uint256 agentId => int256) public agentSortinoBps;

    /// @dev latest update timestamp
    mapping(uint256 agentId => uint256) public lastUpdate;

    event SortinoPushed(uint256 indexed agentId, int256 sortinoBps, uint256 nonce, uint256 timestamp);
    event SignerUpdated(address indexed oldSigner, address indexed newSigner);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _signer) {
        owner = msg.sender;
        signer = _signer;
    }

    /// @notice Push a Sortino update. Signature is over (agentId, sortinoBps, nonce, address(this)).
    function pushSortino(uint256 agentId, int256 sortinoBps, uint256 nonce, bytes calldata sig) external {
        require(nonce == nonces[agentId] + 1, "bad nonce");
        bytes32 digest = keccak256(abi.encodePacked(agentId, sortinoBps, nonce, address(this)));
        bytes32 ethSigned = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));

        address recovered = _recover(ethSigned, sig);
        require(recovered == signer, "bad signer");

        nonces[agentId] = nonce;
        agentSortinoBps[agentId] = sortinoBps;
        lastUpdate[agentId] = block.timestamp;

        emit SortinoPushed(agentId, sortinoBps, nonce, block.timestamp);
    }

    function setSigner(address newSigner) external onlyOwner {
        address oldSigner = signer;
        signer = newSigner;
        emit SignerUpdated(oldSigner, newSigner);
    }

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
