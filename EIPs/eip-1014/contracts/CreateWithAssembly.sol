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
    function deployFoo() public returns (address) {
        address foo;
        bytes memory initCode = type(Foo).creationCode;

        assembly {
            // Load init code into memory
            let codeSize := mload(initCode) // Size of the init code
            let codeOffset := add(initCode, 0x20) // Skip 32 bytes for the array length

            // Call CREATE without sending msg.value
            foo := create(0, codeOffset, codeSize)
            // Check that the contract was successfully created
            if iszero(foo) { revert(0, 0) }
        }

        return foo;
    }

    /// @notice Creating a contract via create with sending ETH to the new address
    function deployBar() public payable returns (address) {
        address bar;
        bytes memory initCode = type(Bar).creationCode;

        assembly {
            let codeSize := mload(initCode)
            let codeOffset := add(initCode, 0x20)
            bar := create(callvalue(), codeOffset, codeSize)
            if iszero(bar) { revert(0, 0) }
        }

        return bar;
    }

    /// @notice Calculate the address of the next contract to be deployed by this contract
    /// @dev Hint: Right after deployment, Deployer’s next nonce = 1
    function computeAddressWithCreate(uint256 _nonce) public view returns (address) {
        address _origin = address(this);
        bytes memory data;

        if (_nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, bytes1(0x80));
        } else if (_nonce <= 0x7f) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, uint8(_nonce));
        } else if (_nonce <= 0xff) {
            data =
                abi.encodePacked(bytes1(0xd7), bytes1(0x94), _origin, bytes1(0x81), uint8(_nonce));
        } else if (_nonce <= 0xffff) {
            data =
                abi.encodePacked(bytes1(0xd8), bytes1(0x94), _origin, bytes1(0x82), uint16(_nonce));
        } else if (_nonce <= 0xffffff) {
            data =
                abi.encodePacked(bytes1(0xd9), bytes1(0x94), _origin, bytes1(0x83), uint24(_nonce));
        } else {
            data =
                abi.encodePacked(bytes1(0xda), bytes1(0x94), _origin, bytes1(0x84), uint32(_nonce));
        }
        return address(uint160(uint256(keccak256(data))));
    }
}
