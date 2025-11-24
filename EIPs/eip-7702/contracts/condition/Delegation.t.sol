// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console, Vm, StdCheats} from "forge-std/Test.sol";
import {Delegation, Target} from "./Delegation.sol";

contract DelegationTest is Test {
    Delegation public delegation;
    Target public target;

    StdCheats.Account public user;
    StdCheats.Account public operator;

    function setUp() external {
        target = new Target();
        delegation = new Delegation();

        user = makeAccount("User");
        operator = makeAccount("Operator");

        vm.label(address(delegation), "Delegation");
        vm.label(address(this), "address(this)");
        vm.label(address(target), "Target");
        vm.label(user.addr, "User");
        vm.label(operator.addr, "Operator");
    }

    function test_checkCondition(uint256 value) external {
        Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(delegation), user.key);

        // Simulate the user calling the target contract directly — the transaction reverts
        vm.expectRevert(Target.EOACallIsNotAllowed.selector);
        vm.prank(user.addr, user.addr);
        target.setValue(value);

        // The operator attaches the `Delegation` smart contract to the user
        vm.startBroadcast(operator.key);
        vm.attachDelegation(signedDelegation);
        vm.stopBroadcast();

        // The operator calls the `setValue` function on the `Delegation` contract on behalf of the user,
        // which will set the `value` on the `Target` smart contract
        vm.prank(operator.addr, operator.addr);
        Delegation(user.addr).setValue(address(target), value);

        // Verify that the value was set (the check was bypassed)
        assertEq(target.getValue(), value);
    }
}
