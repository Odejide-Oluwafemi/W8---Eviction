// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MultiSig} from "src/MultiSig.sol";

contract Vault {
  // Events
  event Deposit(address indexed depositor, uint256 amount);
  event Withdrawal(address indexed withdrawer, uint256 amount);
  event Submission(uint256 indexed txId);
  event Confirmation(uint256 indexed txId, address indexed owner);
  event Execution(uint256 indexed txId);
  event Claim(address indexed claimant, uint256 amount);

  // Errors
  error Vault__OnlyOwnerCanCallThisFunction();
  error Vault__WithdrawFailed();
  error Vault__ContractIsPaused();
  error Vault__InsufficientFunds();
  error Vault__TransactionHasAlreadyBeenExecuted();
  error Vault__TransactionHasAlreadyBeenConfirmed();
  error Vault__InsufficientThresholdSigners();
  error Vault__TransactionExecutionLocked();
  error Vault__TransactionExecutionFailed();
  error Vault__ClaimFailed();
  error Vault__EmergencyWithdrawFailed();
  error Vault__UserNotVerified();

  struct Transaction {
    address to;
    uint256 value;
    bytes data;
    bool executed;
    uint256 confirmations;
    uint256 submissionTime;
    uint256 executionTime;
  }

  MultiSig public immutable multiSig;

  mapping(uint256 => mapping(address => bool)) private confirmed;

  mapping(uint256 => Transaction) private transactions;

  mapping(address => uint256) private balances;

  mapping(address => bool) private claimed;

  uint256 private txCount;

  uint256 private constant TIMELOCK_DURATION = 1 hours;

  uint256 private totalVaultValue;

  bool private paused;


  constructor(address[] memory _owners, uint256 _threshold) payable {
    multiSig = new MultiSig(_owners, _threshold);

    totalVaultValue = msg.value;
  }

// Modifiers
  modifier onlyOwners() {
    if (! multiSig.isOwner(msg.sender)) revert Vault__OnlyOwnerCanCallThisFunction();
    _;
  }

  modifier notPaused() {
    if (paused) revert Vault__ContractIsPaused();
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
    if (balances[msg.sender] < amount) revert Vault__InsufficientFunds();

    balances[msg.sender] -= amount;

    totalVaultValue -= amount;

    // payable(msg.sender).transfer(amount);
    (bool success, ) = msg.sender.call{value: amount}("");

    if (!success) revert Vault__WithdrawFailed();

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
    if (txn.executed) revert Vault__TransactionHasAlreadyBeenExecuted();

    // require(!confirmed[txId][msg.sender]);
    if (confirmed[txId][msg.sender]) revert Vault__TransactionHasAlreadyBeenConfirmed();

    confirmed[txId][msg.sender] = true;

    txn.confirmations++;

    if (txn.confirmations >= multiSig.threshold()) {
      txn.executionTime = block.timestamp + TIMELOCK_DURATION;
    }

    emit Confirmation(txId, msg.sender);
  }

  function executeTransaction(uint256 txId) external {
    Transaction storage txn = transactions[txId];

    // require(txn.confirmations >= threshold);
    if (txn.confirmations < multiSig.threshold()) revert Vault__InsufficientThresholdSigners();

    // require(!txn.executed);
    if (txn.executed) revert Vault__TransactionHasAlreadyBeenExecuted();

    // require(block.timestamp >= txn.executionTime);
    if (block.timestamp > txn.executionTime) revert Vault__TransactionExecutionLocked();

    txn.executed = true;

    (bool s,) = txn.to.call{value: txn.value}(txn.data);

    // require(s);
    if (!s) revert Vault__TransactionExecutionFailed();

    emit Execution(txId);
  }

  function setMerkleRoot(bytes32 root) external onlyOwners {
    multiSig.setMerkleRoot(root);
  }

  function claim(bytes32[] calldata proof, uint256 amount) external notPaused {
    // require(!paused);
    bool verified = multiSig.computeMerkleProof(proof, amount);

    if (!verified) revert Vault__UserNotVerified();

    claimed[msg.sender] = true;

    // payable(msg.sender).transfer(amount);
    (bool success, ) = msg.sender.call{value: amount}("");

    if(!success) revert Vault__ClaimFailed();

    totalVaultValue -= amount;

    emit Claim(msg.sender, amount);
  }

  function emergencyWithdrawAll() external onlyOwners {
    // payable(msg.sender).transfer(address(this).balance);

    (bool success, ) = msg.sender.call{value: address(this).balance}("");

    if (!success) revert Vault__EmergencyWithdrawFailed();
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

      function getOwners() external view returns (address[] memory) {
        return multiSig.getOwners();
    }

    function getThreshold() external view returns (uint) {
      return multiSig.threshold();
    }

    function getTotalVaultValue() external view returns (uint) {
      return totalVaultValue;
    }

    function getBalanceOf(address user) external view returns(uint) {
      return balances[user];
    }
}
