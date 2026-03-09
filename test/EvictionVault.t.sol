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
      // Deposit
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
}
