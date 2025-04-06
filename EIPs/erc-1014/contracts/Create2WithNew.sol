// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Foo {}

contract Bar {
    uint256 public balance;

    constructor() payable {
        balance = msg.value;
    }
}

contract DeployerCreate2 {
    /// @notice Creating a contract via create2 without sending ETH to the new address
    function create2Foo(bytes32 _salt) external returns (address) {
        Foo foo = new Foo{salt: _salt}();

        return address(foo);
    }

    /// @notice Creating a contract via create2 with sending ETH to the new address
    function create2Bar(bytes32 _salt) external payable returns (address) {
        Bar bar = new Bar{value: msg.value, salt: _salt}();

        return address(bar);
    }
}
