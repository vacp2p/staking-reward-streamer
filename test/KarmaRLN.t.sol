// SPDX-License-Identifier: Apache-2.0 OR MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Test.sol";

import "../src/rln/KarmaRLN.sol";
import { IVerifier } from "../src/rln/IVerifier.sol";


// A mock verifier which makes us skip the proof verification.
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
        returns (bool)
    {
        return result;
    }

    function changeResult(bool _result) external {
        result = _result;
    }
}

contract RLNTest is Test {
    event MemberRegistered(uint256 identityCommitment, uint256 messageLimit, uint256 index);
    event MemberWithdrawn(uint256 index);
    event MemberSlashed(uint256 index, address slasher);

    Karma token;
    KarmaRLN rln;
    MockVerifier verifier;

    uint256 depth = 20;
    uint256 identityCommitment0 = 1234;
    uint256 identityCommitment1 = 5678;

    address adminAddr = makeAddr("admin");
    address registerAddr = makeAddr("register");
    address slasherAddr = makeAddr("slasher");

    address user0 = makeAddr("user0");
    address user1 = makeAddr("user1");

    uint256 messageLimit0 = 2;
    uint256 messageLimit1 = 3;

    uint256[8] mockProof =
        [uint256(0), uint256(1), uint256(2), uint256(3), uint256(4), uint256(5), uint256(6), uint256(7)];

    function deployRLN(uint256 _depth) public returns (KarmaRLN) {
        // Deploy KarmaRLN contract
        bytes memory initializeData = abi.encodeCall(KarmaRLN.initialize, (adminAddr, registerAddr, slasherAddr, _depth, address(verifier), address(token)));
        address impl = address(new KarmaRLN());
        // Create upgradeable proxy
        address proxy = address(new ERC1967Proxy(impl, initializeData));
        return KarmaRLN(proxy);
    }

    function deployKarmaToken() public returns (Karma) {
        // Deploy Karma logic contract
        bytes memory initializeData = abi.encodeCall(Karma.initialize, (adminAddr));
        address impl = address(new Karma());
        // Create upgradeable proxy
        address proxy = address(new ERC1967Proxy(impl, initializeData));

        return (Karma(proxy));
    } 

    function setUp() public {
        verifier = new MockVerifier();
        token = deployKarmaToken();
        rln = deployRLN();
    }

    function test_initial_state() public {
        assertEq(rln.SET_SIZE(), 1 << depth);
        assertEq(address(rln.karma()), address(token));
        assertEq(address(rln.verifier()), address(verifier));
        assertEq(rln.identityCommitmentIndex(), 0);
    }

    /* register */

    function test_register_succeeds() public {
        // Test: register one user
        register(user0, identityCommitment0, messageLimit0);
        // Test: register second user
        register(user1, identityCommitment1, messageLimit1);
    }

    function test_register_fails_when_index_exceeds_set_size() public {
        // Set size is (1 << smallDepth) = 2, and thus there can
        // only be 2 members, otherwise reverts.
        uint256 smallDepth = 1;
        KarmaRLN smallRLN = deployRLN(smallDepth);

        // Register the first user
        vm.startPrank(registerAddr);
        smallRLN.register(identityCommitment0, minimalDeposit);
        smallRLN.register(identityCommitment1, minimalDeposit);
        vm.stopPrank();
        // Now tree (set) is full. Try register the third. It should revert.
        uint256 identityCommitment2 = 9999;
        // `register` should revert
        vm.expectRevert("KarmaRLN, register: set is full");
        smallRLN.register(identityCommitment2, minimalDeposit);
        vm.stopPrank();
    }


    function test_register_fails_when_duplicate_identity_commitments() public {
        // Register first with user0 with identityCommitment0
        register(user0, identityCommitment0);
        // Register again with user1 with identityCommitment0
        vm.startPrank(registerAddr);
        // `register` should revert
        vm.expectRevert("KarmaRLN, register: idCommitment already registered");
        rln.register(identityCommitment0, rlnInitialTokenBalance);
        vm.stopPrank();
    }

    function test_exit_succeeds() public {
        // Register first
        register(user0, identityCommitment0);
        // Withdraw user0
        // Make sure proof verification is skipped
        assertEq(verifier.result(), true);
        rln.withdraw(identityCommitment0, mockProof);
        rln.exit(identityCommitment0);

        checkUserIsDeleted(identityCommitment0);
    }

    /* slash */

    function test_slash_succeeds() public {
        // Test: register and get slashed
        register(user0, identityCommitment0, messageLimit0);
        (,, uint256 index) = rln.members(identityCommitment0);
        vm.startPrank(slasherAddr);
        vm.expectEmit(true, true, false, true);
        emit MemberSlashed(index, slashedReceiver);
        // Slash and check balances
        rln.slash(identityCommitment0, mockProof);

        // Check the record of user0 has been deleted
        vm.stopPrank();
        checkUserIsDeleted(identityCommitment0);

        // Test: register, withdraw, ang get slashed before release
        register(user1, identityCommitment1, messageLimit1);
        vm.startPrank(slasherAddr);
        rln.slash(identityCommitment1, slashedReceiver, mockProof);
        vm.stopPrank();
        // Check the record of user1 has been deleted
        checkUserIsDeleted(identityCommitment1);
    }



    function test_slash_fails_when_not_registered() public {
        // It fails if the user is not registered yet
        vm.startPrank(slasherAddr);
        vm.expectRevert("KarmaRLN, slash: member doesn't exist");
        rln.slash(identityCommitment0, slashedReceiver, mockProof);
        vm.stopPrank();
    }

    function test_slash_fails_when_invalid_proof() public {
        // It fails if the proof is invalid
        // Register first
        register(user0, identityCommitment0);
        // Make sure mock verifier always return false
        // And thus the proof is always considered invalid
        verifier.changeResult(false);
        assertEq(verifier.result(), false);
        vm.expectRevert("KarmaRLN, slash: invalid proof");
        // Slash fails because of the invalid proof
        vm.startPrank(slasherAddr);
        rln.slash(identityCommitment0, mockProof);
        vm.stopPrank();
    }

    /* Helpers */
    function getRegisterAmount(uint256 messageLimit) public view returns (uint256) {
        return messageLimit * minimalDeposit;
    }

    function register(address user, uint256 identityCommitment, uint256 messageLimit) public {
        // Mint to user first

        uint256 identityCommitmentIndexBefore = rln.identityCommitmentIndex();
        // User approves to rln and calls register
        vm.startPrank(registerAddr);
        // Ensure event is emitted
        vm.expectEmit(true, true, false, true);
        emit MemberRegistered(identityCommitment, identityCommitmentIndexBefore);
        rln.register(identityCommitment);
        vm.stopPrank();


        // KarmaRLN state
        assertEq(rln.identityCommitmentIndex(), identityCommitmentIndexBefore + 1);
        // User state
        (address userAddress, uint256 index) = rln.members(identityCommitment);
        assertEq(userAddress, user);
        assertEq(index, identityCommitmentIndexBefore);
    }



    function checkUserIsDeleted(uint256 identityCommitment) public {
        (address userAddress, uint256 index) = rln.members(identityCommitment);
        assertEq(userAddress, address(0));
        assertEq(index, 0);


    }

}
