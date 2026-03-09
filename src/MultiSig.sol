// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

contract MultiSig {
error MultiSig__NoOwners();
error MultiSig__InvalidAddress();

    bytes32 public merkleRoot;

    address[] public owners;

    mapping(bytes32 => bool) public usedHashes;

        mapping(address => bool) public isOwner;

    uint256 public threshold;


    event MerkleRootSet(bytes32 indexed newRoot);

    constructor(address[] memory _owners, uint256 _threshold) {
        // require(_owners.length > 0, "no owners");
        if (_owners.length == 0) revert MultiSig__NoOwners();
        threshold = _threshold;

        for (uint i = 0; i < _owners.length; i++) {
            address o = _owners[i];
            // require(o != address(0));
            if (o == address(0)) revert MultiSig__InvalidAddress();
            isOwner[o] = true;
            owners.push(o);
        }
        
    }
    

    function setMerkleRoot(bytes32 root) external {
        merkleRoot = root;
        emit MerkleRootSet(root);
    }

    function computeMerkleProof(bytes32[] calldata proof, uint256 amount) external view returns (bool) {
        // require(!paused);
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        bytes32 computed = MerkleProof.processProof(proof, leaf);

        return computed == merkleRoot;
    }

    function verifySignature(
        address signer,
        bytes32 messageHash,
        bytes memory signature
    ) external view returns (bool) {
        return SignatureChecker.isValidSignatureNow(signer, messageHash, signature);
        // return verify(messageHash, signature) == signer;
        // return messageHash.verify()
    }

}