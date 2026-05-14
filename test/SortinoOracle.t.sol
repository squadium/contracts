// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {SortinoOracle} from "../src/SortinoOracle.sol";

contract SortinoOracleTest is Test {
    SortinoOracle oracle;
    uint256 signerPk = 0xA11CE;
    address signer;
    address attackerSigner = address(0xBAD);

    function setUp() public {
        signer = vm.addr(signerPk);
        oracle = new SortinoOracle(signer);
    }

    function _sign(uint256 agentId, int256 sortinoBps, uint256 nonce) internal view returns (bytes memory) {
        bytes32 digest = keccak256(abi.encodePacked(agentId, sortinoBps, nonce, address(oracle)));
        bytes32 ethSigned = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, ethSigned);
        return abi.encodePacked(r, s, v);
    }

    function test_pushSortino_validSignature() public {
        bytes memory sig = _sign(1, 25_000, 1);
        oracle.pushSortino(1, 25_000, 1, sig);

        assertEq(oracle.agentSortinoBps(1), 25_000);
        assertEq(oracle.nonces(1), 1);
        assertGt(oracle.lastUpdate(1), 0);
    }

    function test_pushSortino_revertsOnReplay() public {
        bytes memory sig = _sign(1, 25_000, 1);
        oracle.pushSortino(1, 25_000, 1, sig);

        vm.expectRevert("bad nonce");
        oracle.pushSortino(1, 25_000, 1, sig);
    }

    function test_pushSortino_revertsOnBadNonce() public {
        bytes memory sig = _sign(1, 25_000, 5);
        vm.expectRevert("bad nonce");
        oracle.pushSortino(1, 25_000, 5, sig);
    }

    function test_pushSortino_revertsOnBadSignature() public {
        // Sign with a different (attacker) key
        uint256 attackerPk = 0xDEAD;
        bytes32 digest = keccak256(abi.encodePacked(uint256(1), int256(25_000), uint256(1), address(oracle)));
        bytes32 ethSigned = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attackerPk, ethSigned);
        bytes memory badSig = abi.encodePacked(r, s, v);

        vm.expectRevert("bad signer");
        oracle.pushSortino(1, 25_000, 1, badSig);
    }

    function test_pushSortino_negativeSortinoOk() public {
        bytes memory sig = _sign(7, -5_000, 1);
        oracle.pushSortino(7, -5_000, 1, sig);
        assertEq(oracle.agentSortinoBps(7), -5_000);
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
}
