// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console, Vm, StdCheats} from "forge-std/Test.sol";
import {DelegationFirst, DelegationSecond} from "./Delegation.sol";

contract DelegationTest is Test {
    uint256 private constant _INITIAL_VALUE = 1;
    DelegationFirst public delegationFirst;
    DelegationSecond public delegationSecond;

    StdCheats.Account public user;
    StdCheats.Account public operator;

    function setUp() external {
        delegationFirst = new DelegationFirst();
        delegationSecond = new DelegationSecond();

        user = makeAccount("User");
        operator = makeAccount("Operator");
    }

    function test_storageCollision(uint256 value, bytes32 hashValue) external {
        // Attach the first smart contract
        vm.startBroadcast(operator.key);
        vm.signAndAttachDelegation(address(delegationFirst), user.key);
        vm.stopBroadcast();

        // Set a value in the smart contract's storage
        DelegationFirst(user.addr).setValue(value);
        assertEq(DelegationFirst(user.addr).getValue(), value);

        // Attach the second smart contract
        vm.startBroadcast(operator.key);
        vm.signAndAttachDelegation(address(delegationSecond), user.key);
        vm.stopBroadcast();

        // Set a hash value in the smart contract's storage
        DelegationSecond(user.addr).setHash(hashValue);
        assertEq(DelegationSecond(user.addr).getHash(), hashValue);

        // Reattach the first smart contract
        vm.startBroadcast(operator.key);
        vm.signAndAttachDelegation(address(delegationFirst), user.key);
        vm.stopBroadcast();

        assertNotEq(DelegationFirst(user.addr).getValue(), value); // This proves that the value was overwritten
    }
}
