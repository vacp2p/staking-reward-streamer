// SPDX-License-Identifier: Apache-2.0 OR MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/rln/KarmaRLN.sol";
import { IVerifier } from "../src/rln/IVerifier.sol";

/// @dev A mock verifier that allows toggling proof validity.
contract MockVerifier is IVerifier {
    bool public result;

    constructor() {
        result = true;
    }

    function verifyProof(
        uint256[2] memory,
        uint256[2][2] memory,
        uint256[2] memory,
        uint256[2] memory
    )
        external
        view
        override
        returns (bool)
    {
        return result;
    }

    function changeResult(bool _result) external {
        result = _result;
    }
}

contract RLNTest is Test {
    KarmaRLN public rln;
    MockVerifier public verifier;

    uint256 private constant DEPTH = 2; // for most tests
    uint256 private constant SMALL_DEPTH = 1; // for “full” test

    // Sample identity commitments
    uint256 private identityCommitment0 = 1234;
    uint256 private identityCommitment1 = 5678;
    uint256 private identityCommitment2 = 9999;

    // Sample SNARK proof (8‐element array)
    uint256[8] private mockProof =
        [uint256(0), uint256(1), uint256(2), uint256(3), uint256(4), uint256(5), uint256(6), uint256(7)];

    // Role‐holders
    address private adminAddr;
    address private registerAddr;
    address private slasherAddr;

    function setUp() public {
        // Assign deterministic addresses
        adminAddr = makeAddr("admin");
        registerAddr = makeAddr("register");
        slasherAddr = makeAddr("slasher");

        // Deploy mock verifier
        verifier = new MockVerifier();

        // Deploy KarmaRLN via UUPS proxy with DEPTH = 2
        rln = _deployRLN(DEPTH, address(verifier));

        // Sanity‐check that roles were assigned correctly
        assertTrue(rln.hasRole(rln.DEFAULT_ADMIN_ROLE(), adminAddr));
        assertTrue(rln.hasRole(rln.REGISTER_ROLE(), registerAddr));
        assertTrue(rln.hasRole(rln.SLASHER_ROLE(), slasherAddr));
    }

    /// @dev Deploys a new KarmaRLN instance (behind ERC1967Proxy).
    function _deployRLN(uint256 depth, address verifierAddr) internal returns (KarmaRLN) {
        bytes memory initData = abi.encodeCall(
            KarmaRLN.initialize,
            (
                adminAddr,
                slasherAddr,
                registerAddr,
                depth,
                verifierAddr,
                address(0) // token address unused in these tests
            )
        );
        address impl = address(new KarmaRLN());
        address proxy = address(new ERC1967Proxy(impl, initData));
        return KarmaRLN(proxy);
    }

    /* ---------- INITIAL STATE ---------- */

    function test_initial_state() public {
        // SET_SIZE should be 2^DEPTH = 4
        assertEq(rln.SET_SIZE(), uint256(1) << DEPTH);

        // No identities registered yet
        assertEq(rln.identityCommitmentIndex(), 0);

        // members(...) should return (address(0), 0) for any commitment
        (address user0, uint256 idx0) = _memberData(identityCommitment0);
        assertEq(user0, address(0));
        assertEq(idx0, 0);

        // Verifier address matches
        assertEq(address(rln.verifier()), address(verifier));
    }

    /* ---------- REGISTER ---------- */

    function test_register_succeeds() public {
        // Register first identity
        uint256 indexBefore = rln.identityCommitmentIndex();
        vm.startPrank(registerAddr);
        vm.expectEmit(true, false, false, true);
        emit KarmaRLN.MemberRegistered(identityCommitment0, indexBefore);
        rln.register(identityCommitment0);
        vm.stopPrank();

        assertEq(rln.identityCommitmentIndex(), indexBefore + 1);
        (address u0, uint256 i0) = _memberData(identityCommitment0);
        assertEq(u0, registerAddr);
        assertEq(i0, indexBefore);

        // Register second identity
        indexBefore = rln.identityCommitmentIndex();
        vm.startPrank(registerAddr);
        vm.expectEmit(true, false, false, true);
        emit KarmaRLN.MemberRegistered(identityCommitment1, indexBefore);
        rln.register(identityCommitment1);
        vm.stopPrank();

        assertEq(rln.identityCommitmentIndex(), indexBefore + 1);
        (address u1, uint256 i1) = _memberData(identityCommitment1);
        assertEq(u1, registerAddr);
        assertEq(i1, indexBefore);
    }

    function test_register_fails_when_index_exceeds_set_size() public {
        // Deploy a small RLN with depth = 1 => SET_SIZE = 2
        KarmaRLN smallRLN = _deployRLN(SMALL_DEPTH, address(verifier));
        address smallRegister = registerAddr;

        // Fill up both slots
        vm.startPrank(smallRegister);
        smallRLN.register(identityCommitment0);
        smallRLN.register(identityCommitment1);
        vm.stopPrank();

        // Now the set is full (2 members). Attempt a third registration.
        vm.startPrank(smallRegister);
        vm.expectRevert(bytes("RLN, register: set is full"));
        smallRLN.register(identityCommitment2);
        vm.stopPrank();
    }

    function test_register_fails_when_duplicate_identity_commitment() public {
        // Register once
        vm.startPrank(registerAddr);
        rln.register(identityCommitment0);
        vm.stopPrank();

        // Attempt to register the same commitment again
        vm.startPrank(registerAddr);
        vm.expectRevert(bytes("RLN, register: idCommitment already registered"));
        rln.register(identityCommitment0);
        vm.stopPrank();
    }

    /* ---------- EXIT ---------- */

    function test_exit_succeeds() public {
        // Register the identity
        vm.startPrank(registerAddr);
        rln.register(identityCommitment0);
        vm.stopPrank();

        // Ensure mock verifier returns true by default
        assertTrue(verifier.result());

        // Call exit with a valid proof
        vm.startPrank(registerAddr);
        vm.expectEmit(false, false, false, true);
        emit KarmaRLN.MemberExited(0);
        rln.exit(identityCommitment0, mockProof);
        vm.stopPrank();

        // After exit, the member record should be cleared
        (address u0, uint256 i0) = _memberData(identityCommitment0);
        assertEq(u0, address(0));
        assertEq(i0, 0);
    }

    function test_exit_fails_when_not_registered() public {
        // Attempt exit without prior registration
        vm.startPrank(registerAddr);
        vm.expectRevert(bytes("RLN, withdraw: member doesn't exist"));
        rln.exit(identityCommitment1, mockProof);
        vm.stopPrank();
    }

    function test_exit_fails_when_invalid_proof() public {
        // Register the identity
        vm.startPrank(registerAddr);
        rln.register(identityCommitment0);
        vm.stopPrank();

        // Make proof invalid
        verifier.changeResult(false);
        assertFalse(verifier.result());

        // Attempt exit with invalid proof
        vm.startPrank(registerAddr);
        vm.expectRevert(bytes("RLN, withdraw: invalid proof"));
        rln.exit(identityCommitment0, mockProof);
        vm.stopPrank();
    }

    /* ---------- SLASH ---------- */

    function test_slash_succeeds() public {
        // Register the identity first
        vm.startPrank(registerAddr);
        rln.register(identityCommitment1);
        vm.stopPrank();

        // Retrieve the assigned index
        (, uint256 index1) = _memberData(identityCommitment1);

        // Slash with a valid proof
        vm.startPrank(slasherAddr);
        vm.expectEmit(false, true, false, true);
        emit KarmaRLN.MemberSlashed(index1, slasherAddr);
        rln.slash(identityCommitment1, mockProof);
        vm.stopPrank();

        // After slash, the member record should be cleared
        (address u1, uint256 i1) = _memberData(identityCommitment1);
        assertEq(u1, address(0));
        assertEq(i1, 0);
    }

    function test_slash_fails_when_not_registered() public {
        // Attempt to slash a non‐existent identity
        vm.startPrank(slasherAddr);
        vm.expectRevert(bytes("RLN, slash: member doesn't exist"));
        rln.slash(identityCommitment0, mockProof);
        vm.stopPrank();
    }

    function test_slash_fails_when_invalid_proof() public {
        // Register the identity
        vm.startPrank(registerAddr);
        rln.register(identityCommitment0);
        vm.stopPrank();

        // Make proof invalid
        verifier.changeResult(false);
        assertFalse(verifier.result());

        // Attempt to slash with invalid proof
        vm.startPrank(slasherAddr);
        vm.expectRevert(bytes("RLN, slash: invalid proof"));
        rln.slash(identityCommitment0, mockProof);
        vm.stopPrank();
    }

    /* ========== HELPERS ========== */

    /// @dev Returns (userAddress, index) for a given identityCommitment.
    function _memberData(uint256 commitment) internal view returns (address userAddress, uint256 index) {
        (userAddress, index) = rln.members(commitment);
        return (userAddress, index);
    }
}
