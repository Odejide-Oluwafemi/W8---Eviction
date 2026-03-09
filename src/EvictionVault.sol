// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

contract EvictionVault {
    // Errors
    error NoOwners();
    error OnlyOwnerCanCallThisFunction();
    error WithdrawFailed();
    error InvalidAddress();
    error ContractIsPaused();
    error InsufficientFunds();
    error TransactionHasAlreadyBeenExecuted();
    error TransactionHasAlreadyBeenConfirmed();
    error InsufficientThresholdSigners();
    error TransactionExecutionLocked();
    error TransactionExecutionFailed();
    error ClaimFailed();
    error EmergencyWithdrawFailed();

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        uint256 submissionTime;
        uint256 executionTime;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;

    uint256 public threshold;

    mapping(uint256 => mapping(address => bool)) public confirmed;
    mapping(uint256 => Transaction) public transactions;

    uint256 public txCount;

    mapping(address => uint256) public balances;

    bytes32 public merkleRoot;

    mapping(address => bool) public claimed;

    mapping(bytes32 => bool) public usedHashes;

    uint256 public constant TIMELOCK_DURATION = 1 hours;

    uint256 public totalVaultValue;

    bool public paused;

    event Deposit(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);
    event Submission(uint256 indexed txId);
    event Confirmation(uint256 indexed txId, address indexed owner);
    event Execution(uint256 indexed txId);
    event MerkleRootSet(bytes32 indexed newRoot);
    event Claim(address indexed claimant, uint256 amount);

    constructor(address[] memory _owners, uint256 _threshold) payable {
        // require(_owners.length > 0, "no owners");
        if (_owners.length == 0) revert NoOwners();
        threshold = _threshold;

        for (uint i = 0; i < _owners.length; i++) {
            address o = _owners[i];
            // require(o != address(0));
            if (o == address(0)) revert InvalidAddress();
            isOwner[o] = true;
            owners.push(o);
        }
        totalVaultValue = msg.value;
    }

    // Modifiers
    modifier onlyOwners() {
        if (!isOwner[msg.sender]) revert OnlyOwnerCanCallThisFunction();

        _;
    }

    modifier notPaused() {
        if (paused) revert ContractIsPaused();
        _;
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        totalVaultValue += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        totalVaultValue += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external notPaused {
        // require(!paused, "paused");

        // require(balances[msg.sender] >= amount);
        if (balances[msg.sender] < amount) revert InsufficientFunds();
        balances[msg.sender] -= amount;
        totalVaultValue -= amount;
        // payable(msg.sender).transfer(amount);
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert WithdrawFailed();
        emit Withdrawal(msg.sender, amount);
    }

    function submitTransaction(address to, uint256 value, bytes calldata data) external notPaused onlyOwners {
        // require(!paused);
        // require(isOwner[msg.sender]);
        uint256 id = txCount++;
        transactions[id] = Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 1,
            submissionTime: block.timestamp,
            executionTime: 0
        });
        confirmed[id][msg.sender] = true;
        emit Submission(id);
    }

    function confirmTransaction(uint256 txId) external notPaused onlyOwners {
        // require(!paused);
        // require(isOwner[msg.sender]);
        Transaction storage txn = transactions[txId];
        // require(!txn.executed);
        if (txn.executed) revert TransactionHasAlreadyBeenExecuted();
        // require(!confirmed[txId][msg.sender]);
        if (confirmed[txId][msg.sender]) revert TransactionHasAlreadyBeenConfirmed();
        confirmed[txId][msg.sender] = true;
        txn.confirmations++;
        if (txn.confirmations == threshold) {
            txn.executionTime = block.timestamp + TIMELOCK_DURATION;
        }
        emit Confirmation(txId, msg.sender);
    }

    function executeTransaction(uint256 txId) external {
        Transaction storage txn = transactions[txId];
        // require(txn.confirmations >= threshold);
        if (txn.confirmations < threshold) revert InsufficientThresholdSigners();
        // require(!txn.executed);
        if (txn.executed) revert TransactionHasAlreadyBeenExecuted();
        // require(block.timestamp >= txn.executionTime);
        if (block.timestamp > txn.executionTime) revert TransactionExecutionLocked();
        txn.executed = true;
        (bool s,) = txn.to.call{value: txn.value}(txn.data);
        // require(s);
        if (!s) revert TransactionExecutionFailed();
        emit Execution(txId);
    }

    function setMerkleRoot(bytes32 root) external onlyOwners {
        merkleRoot = root;
        emit MerkleRootSet(root);
    }

    function claim(bytes32[] calldata proof, uint256 amount) external notPaused {
        // require(!paused);
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        bytes32 computed = MerkleProof.processProof(proof, leaf);
        require(computed == merkleRoot);
        require(!claimed[msg.sender]);
        claimed[msg.sender] = true;
        // payable(msg.sender).transfer(amount);
        (bool success, ) = msg.sender.call{value: amount} ("");
        if(!success) revert ClaimFailed();
        totalVaultValue -= amount;
        emit Claim(msg.sender, amount);
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

    function emergencyWithdrawAll() external onlyOwners {
        // payable(msg.sender).transfer(address(this).balance);

        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        
        if (!success) revert EmergencyWithdrawFailed();
        // require(success, "Emergency Withdrawal Failed");

        totalVaultValue = 0;
    }

    function pause() external onlyOwners {
        // require(isOwner[msg.sender]);
        paused = true;
    }

    function unpause() external onlyOwners {
        // require(isOwner[msg.sender]);
        paused = false;
    }
}