// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Foo {}

contract Bar {
    uint256 public balance;

    constructor() payable {
        balance = msg.value;
    }
}
contract Deployer {
    /// @notice Creating a contract via create without sending ETH to the new address
    function createFoo() external returns (address) {
        Foo foo = new Foo();

        return address(foo);
    }

    /// @notice Creating a contract via create with sending ETH to the new address
    function createBar() external payable returns (address) {
        Bar bar = new Bar{value: msg.value}();

        return address(bar);
    }
}
