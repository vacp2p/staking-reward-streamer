// SPDX-License-Identifier: Apache-2.0 OR MIT
pragma solidity 0.8.26;

import "../Karma.sol";
import { IVerifier } from "./IVerifier.sol";

/// @title Rate-Limiting Nullifier registry contract
/// @dev This contract allows you to register RLN commitment and withdraw/slash.
contract KarmaRLN {
    /// @dev User metadata struct.
    /// @param userAddress: address of depositor;
    struct User {
        address userAddress;
        uint256 index;
    }

    /// @dev Maximal rate.
    uint256 public immutable TIER_SIZE;

    /// @dev Registry set size (1 << DEPTH).
    uint256 public immutable SET_SIZE;

    /// @dev Current index where identityCommitment will be stored.
    uint256 public identityCommitmentIndex;

    /// @dev Registry set. The keys are `identityCommitment`s.
    /// The values are addresses of accounts that call `register` transaction.
    mapping(uint256 => User) public members;

    /// @dev Karma Token used for registering.
    Karma public immutable karma;

    /// @dev Groth16 verifier.
    IVerifier public immutable verifier;

    /// @dev Emmited when a new member registered.
    /// @param identityCommitment: `identityCommitment`;
    /// @param index: idCommitmentIndex value.
    event MemberRegistered(uint256 identityCommitment, uint256 index);

    /// @dev Emmited when a member was withdrawn.
    /// @param index: index of `identityCommitment`;
    event MemberExited(uint256 index);

    /// @dev Emmited when a member was slashed.
    /// @param index: index of `identityCommitment`;
    /// @param slasher: address of slasher (msg.sender).
    event MemberSlashed(uint256 index, address slasher);

    /// @param depth: depth of the merkle tree;
    /// @param _token: address of the ERC20 contract;
    /// @param _verifier: address of the Groth16 Verifier.
    constructor(uint256 depth, address _verifier, address _token) {
        SET_SIZE = 1 << depth;

        karma = Karma(_token);
        verifier = IVerifier(_verifier);
    }

    /// @dev Adds `identityCommitment` to the registry set and takes the necessary stake amount.
    ///
    /// NOTE: The set must not be full.
    ///
    /// @param identityCommitment: `identityCommitment`;
    function register(uint256 identityCommitment) external {
        uint256 index = identityCommitmentIndex;
        uint256 amount = karma.balanceOf(msg.sender);
        require(index < SET_SIZE, "RLN, register: set is full");
        require(members[identityCommitment].userAddress == address(0), "RLN, register: idCommitment already registered");

        members[identityCommitment] = User(msg.sender, index);
        emit MemberRegistered(identityCommitment, index);

        unchecked {
            identityCommitmentIndex = index + 1;
        }
    }

    /// @dev Request for exit.
    /// @param identityCommitment: `identityCommitment`;
    /// @param proof: snarkjs's format generated proof (without public inputs) packed consequently.
    function exit(uint256 identityCommitment, uint256[8] calldata proof) external {
        User memory member = members[identityCommitment];
        require(member.userAddress != address(0), "RLN, withdraw: member doesn't exist");
        require(_verifyProof(identityCommitment, proof), "RLN, withdraw: invalid proof");

        delete members[identityCommitment];
        emit MemberExited(member.index);
    }

    /// @dev Slashes identity with identityCommitment.
    /// @param identityCommitment: `identityCommitment`;
    /// @param proof: snarkjs's format generated proof (without public inputs) packed consequently.
    function slash(uint256 identityCommitment, uint256[8] calldata proof) external {
        User memory member = members[identityCommitment];
        require(member.userAddress != address(0), "RLN, slash: member doesn't exist");
        require(_verifyProof(identityCommitment, proof), "RLN, slash: invalid proof");

        //karma.slash(member.userAddress);
        delete members[identityCommitment];

        emit MemberSlashed(member.index, msg.sender);
    }

    /// @dev Groth16 proof verification
    function _verifyProof(uint256 identityCommitment, uint256[8] calldata proof) internal view returns (bool) {
        return verifier.verifyProof(
            [proof[0], proof[1]],
            [[proof[2], proof[3]], [proof[4], proof[5]]],
            [proof[6], proof[7]],
            [identityCommitment, uint256(0)]
        );
    }
}
