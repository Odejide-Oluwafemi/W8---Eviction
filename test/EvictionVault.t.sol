// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {MultiSig} from "src/MultiSig.sol";

contract EvictionVaultTest is Test {
    error Vault__InsufficientFunds();
    error Vault__ContractIsPaused();
    error Vault__OnlyOwnerCanCallThisFunction();
    error Vault__TransactionHasAlreadyBeenConfirmed();
    error Vault__UserNotVerified();
    error Vault__AlreadyClaimed();

    struct Transaction {
      address to;
      uint256 value;
      bytes data;
      bool executed;
      uint256 confirmations;
      uint256 submissionTime;
      uint256 executionTime;
    }

    Vault public vault;

    address[] owners = [
        makeAddr("Owner 1"),
        makeAddr("Owner 2"),
        makeAddr("Owner 3"),
        makeAddr("Owner 4"),
        makeAddr("Owner 5")
    ];

    uint256 constant THRESHOLD = 3;
    
    function setUp() public {
        vault = new Vault(owners, THRESHOLD);
    }

    function testMultiSigDeploys() public view {
      assert(address(vault.multiSig()) != address(0));
    }



    function testMultiSigParametersAreSet() public view {
      // Test for Owners Array
      address[] memory _owners = vault.getOwners();

      assertEq(owners.length, _owners.length);

      for (uint i; i < owners.length; i++) {
        assertEq(_owners[i], owners[i]);
      }

      // Test for Threshold
      assertEq(vault.getThreshold(), THRESHOLD);
    }

    function testDeposit() public {
      address user = owners[0];

      uint totalVaultValueBefore = vault.getTotalVaultValue();
      uint balanceBefore = vault.getBalanceOf(user);
      uint depositAmount = 1 ether;

      vm.deal(user, depositAmount);
      vm.prank(user);

      vault.deposit{value: depositAmount}();

      uint totalVaultValueAfter = vault.getTotalVaultValue();
      uint balanceAfter = vault.getBalanceOf(user);

      assert(balanceAfter == (balanceBefore + depositAmount));
      assert(totalVaultValueAfter == (totalVaultValueBefore + depositAmount));
    }

    function testCannotWithdrawWithInsufficientFunds() public {
      vm.startPrank(owners[0]);

      vm.expectRevert(Vault__InsufficientFunds.selector);
      vault.withdraw(123);

      vm.stopPrank();
    }

    function testCannotWithdrawWhenVaultIsPaused() public {
      vm.startPrank(owners[0]);

      vault.pause();

      vm.expectRevert(Vault__ContractIsPaused.selector);
      vault.withdraw(123);

      vm.stopPrank();
    }

    function testSuccessfullyWithdraws() public {
      // Deposit First
      address user = owners[0];

      uint depositAmount = 1 ether;

      vm.deal(user, depositAmount);
      vm.prank(user);

      vault.deposit{value: depositAmount}();

      uint balanceBeforeWithdraw = vault.getBalanceOf(user);
      uint totalVaultValueBeforeWithdraw = vault.getTotalVaultValue();

      // Withdraw
      vm.prank(user);
      vault.withdraw(depositAmount);

      uint balanceAfterWithdraw = vault.getBalanceOf(user);
      uint totalVaultValueAfterWithdraw = vault.getTotalVaultValue();

      assertEq(balanceAfterWithdraw, balanceBeforeWithdraw - depositAmount);
      assertEq(totalVaultValueAfterWithdraw, totalVaultValueBeforeWithdraw - depositAmount);
    }

    function testCannotSubmitTransactionWhenPaused() public {
      address to = address(0x1);
      uint value = 123;
      bytes memory data = bytes("");

      vm.startPrank(owners[0]);

      vault.pause();
      vm.expectRevert(Vault__ContractIsPaused.selector);

      vault.submitTransaction(to, value, data);

      vm.stopPrank();
    }

    function testANonRegisteredOwnerCannotSubmitTransaction() public {
      address to = address(0x1);
      uint value = 123;
      bytes memory data = bytes("");

      vm.startPrank(to);
      vm.expectRevert(Vault__OnlyOwnerCanCallThisFunction.selector);

      vault.submitTransaction(to, value, data);

      vm.stopPrank();
    }

    function testSuccessfullySubmitsTransaction() public {
      address owner = owners[0];

      address to = address(0x1);
      uint value = 123;
      bytes memory data = bytes("");

      uint txCountBefore = vault.getTxCount();

      vm.startPrank(owner);

      vault.submitTransaction(to, value, data);

      uint txCountAfter = vault.getTxCount();

      assertEq(txCountAfter, txCountBefore + 1);
      assertEq(vault.getTransaction(txCountBefore).to, to);
      assert(vault.isTransactionConfirmedByOwner(txCountBefore, owner) == true);

      vm.stopPrank();
    }

    function testCannotConfirmTransactionTwiceNeitherCanSubmitterConfirm() public {
      // First Submit a Transaction
      address owner = owners[0];

      address to = address(0x1);
      uint value = 123;
      bytes memory data = bytes("");


      vm.startPrank(owner);

      uint txId = vault.getTxCount();

      vault.submitTransaction(to, value, data);

      // Confirmation Fails
      vm.expectRevert(Vault__TransactionHasAlreadyBeenConfirmed.selector);
      vault.confirmTransaction(txId);

      vm.stopPrank();
    }

    function testSuccessfulyConfirms() public {
      // First Submit a Transaction
      address owner = owners[0];

      address to = address(0x1);
      uint value = 123;
      bytes memory data = bytes("");


      vm.startPrank(owner);

      uint txId = vault.getTxCount();

      vault.submitTransaction(to, value, data);

      vm.stopPrank();

      // Confirmation Succeeds
      vm.prank(owners[1]);
      vault.confirmTransaction(txId);
    }

    function testTransactionExecution() public {
      // First Submit a Transaction
      address owner = owners[0];
      vm.deal(owner, 3 ether);

      uint depositAmount = 1 ether;
      address to = address(0x1);
      uint value = 123;
      bytes memory data = bytes("");

      vm.startPrank(owner);

      vault.deposit{value: depositAmount}();

      uint txId = vault.getTxCount();

      vault.submitTransaction(to, value, data);

      vm.stopPrank();

      // Get 2 more confirmations
      vm.prank(owners[1]);
      vault.confirmTransaction(txId);

      vm.prank(owners[2]);
      vault.confirmTransaction(txId);

      vm.prank(owner);
      vault.executeTransaction(txId);

      assert(vault.getTransaction(txId).executed == true);
    }

    function testClaim() public {
        address user1 = makeAddr("user1");
        uint256 amount1 = 1 ether;
        address user2 = makeAddr("user2");
        uint256 amount2 = 2 ether;

        bytes32 leaf1 = keccak256(abi.encodePacked(user1, amount1));
        bytes32 leaf2 = keccak256(abi.encodePacked(user2, amount2));

        // Sort leaves and compute root
        bytes32 root;
        if (leaf1 < leaf2) {
            root = keccak256(abi.encodePacked(leaf1, leaf2));
        } else {
            root = keccak256(abi.encodePacked(leaf2, leaf1));
        }

        // Set Merkle root (only owners can do this)
        vm.prank(owners[0]);
        vault.setMerkleRoot(root);

        // Fund vault so it has enough to pay out claims
        vm.prank(owners[0]);
        vm.deal(owners[0], 10 ether);
        vault.deposit{value: 10 ether}();

        // Prepare proof for user1
        bytes32[] memory proof1 = new bytes32[](1);
        proof1[0] = leaf2;

        // User 1 claims
        uint256 balanceBefore1 = user1.balance;
        vm.prank(user1);
        vault.claim(proof1, amount1);
        assertEq(user1.balance, balanceBefore1 + amount1);

        // Cannot claim twice
        vm.expectRevert(Vault__AlreadyClaimed.selector);
        vm.prank(user1);
        vault.claim(proof1, amount1);

        // User 2 claims
        bytes32[] memory proof2 = new bytes32[](1);
        proof2[0] = leaf1;
        uint256 balanceBefore2 = user2.balance;
        vm.prank(user2);
        vault.claim(proof2, amount2);
        assertEq(user2.balance, balanceBefore2 + amount2);

        // Random user cannot claim with invalid proof
        address attacker = makeAddr("attacker");
        vm.expectRevert(Vault__UserNotVerified.selector);
        vm.prank(attacker);
        vault.claim(proof1, amount1);
    }
}
