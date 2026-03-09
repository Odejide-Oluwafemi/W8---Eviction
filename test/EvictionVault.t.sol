// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {MultiSig} from "src/MultiSig.sol";

contract EvictionVaultTest is Test {
    error Vault__InsufficientFunds();
    error Vault__ContractIsPaused();

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

    
}
