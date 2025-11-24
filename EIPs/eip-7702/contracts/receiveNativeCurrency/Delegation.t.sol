// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console, Vm, StdCheats} from "forge-std/Test.sol";
import {Delegation} from "./Delegation.sol";

contract DelegationTest is Test {
    Delegation public delegation;

    StdCheats.Account public user;
    StdCheats.Account public operator;

    function setUp() external {
        delegation = new Delegation();

        user = makeAccount("User");
        operator = makeAccount("Operator");

        vm.label(address(delegation), "Delegation");
        vm.label(address(this), "address(this)");
        vm.label(user.addr, "User");
        vm.label(operator.addr, "Operator");
    }

    function test_checkSendNativeCurrency(uint256 value) external {
        Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(delegation), user.key);

        // The operator attaches the `Delegation` smart contract to the user
        vm.startBroadcast(operator.key);
        vm.attachDelegation(signedDelegation);
        vm.stopBroadcast();

        // Attempt to send native currency — the transaction will revert
        (bool success,) = user.addr.call{value: value}("");

        assertFalse(success);
    }
}
