// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";

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
    // function testOwnersAreSet
}
