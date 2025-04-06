// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract TestContract {
    address public owner;
    uint256 public foo;

    constructor(address _owner, uint256 _foo) payable {
        owner = _owner;
        foo = _foo;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

contract FactoryAssembly {
    event Deployed(address addr, uint256 salt);

    // 1. Getting the contract bytecode for deployment
    // NOTE: _owner and _foo are constructor arguments for TestContract

    function getBytecode(address _owner, uint256 _foo)
        public
        pure
        returns (bytes memory)
    {
        bytes memory bytecode = type(TestContract).creationCode;

        return abi.encodePacked(bytecode, abi.encode(_owner, _foo));
    }

    // 2. Calculate the address of the contract to be deployed
    // NOTE: _salt is a random number used for address creation.
    function getAddress(bytes memory bytecode, uint256 _salt)
        public
        view
        returns (address)
    {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(this), _salt, keccak256(bytecode)
            )
        );

        // NOTE: Convert the last 20 bytes of the hash to an address
        return address(uint160(uint256(hash)));
    }

    // 3. Deploying the contract
    // NOTE:
    // Check the Deployed event log, which contains the address of the deployed TestContract.
    // The address in the log should match the address calculated above.
    function deploy(bytes memory bytecode, uint256 _salt) public payable {
        address addr;

        /*
        NOTE: How to call create2

        create2(v, p, n, s)
        create a new contract with code in memory from p to p + n
        and send v ETH  
        and return the new address  
        where the new address = first 20 bytes of keccak256(0xff + address(this) + s + keccak256(mem[p…(p+n)]))
              s = big-endian 256-bit value
        */
        assembly {
            addr :=
                create2(
                    callvalue(), // ETH sent with the current call
                    // Actual code starts after skipping the first 32 bytes
                    add(bytecode, 0x20),
                    mload(bytecode), // Load the size of the code contained in the first 32 bytes
                    _salt // Salt from the function arguments
                )

            if iszero(extcodesize(addr)) { revert(0, 0) }
        }

        emit Deployed(addr, _salt);
    }
}
