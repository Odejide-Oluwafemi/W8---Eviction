// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {MultiSig} from "src/MultiSig.sol";

contract EvictionVaultTest is Test {
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
}
