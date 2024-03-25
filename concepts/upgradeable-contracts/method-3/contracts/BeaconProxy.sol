// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

/**
 * To understand the contracts, it's best to deploy them using Remix.
 * Deployment order for testing in remix:
 *      1. Deploy the Logic contract
 *      2. Deploy the Beacon contract (address Logic, address Owner)
 *      3. Deploy the LogicProxy contract (address Beacon, 0x)
 *      4. Deploy the LogicProxy2 contract (address Beacon, 0x)
 *      5. Deploy the new Logic2 contract
 *      6. Call upgradeTo(address Logic2) on the Beacon contract
 *      7. Call the getImplementation() function on each LogicProxy contract to verify the logic contract change
 */

/// Logic Contract

contract Logic {
    uint256 private _value;

    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    function retrieve() public view returns (uint256) {
        return _value;
    }
}

/// Smart Contract Logic for Upgrading
contract Logic2 {
    uint256 private _value;

    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    function increment() public {
        _value += 1;
    }

    function retrieve() public view returns (uint256) {
        return _value;
    }
}

// Beacon Contract
contract Beacon is UpgradeableBeacon {
    // To update the logic for all proxy contracts, the upgradeTo() function on the Beacon contract needs to be called
    constructor(address _implementation, address _owner) UpgradeableBeacon(_implementation, _owner) {}
}

/// First Proxy Contract
contract LogicProxy is BeaconProxy {
    constructor(address _beacon, bytes memory _data) BeaconProxy(_beacon, _data) {}

    /// @notice Returns the address of the Beacon contract
    function getBeacon() public view returns (address) {
        return _getBeacon();
    }

    /// @notice Returns the address of the installed logic contract for the proxy
    function getImplementation() public view returns (address) {
        return _implementation();
    }

    /// @notice return proxy's description
    function getProxyDescription() external pure returns (string memory) {
        return "First proxy";
    }

    receive() external payable {}
}

///  Second smart contract proxy
contract LogicProxy2 is BeaconProxy {
    constructor(address _beacon, bytes memory _data) BeaconProxy(_beacon, _data) {}

    /// @notice returns beacon SC adress
    function getBeacon() public view returns (address) {
        return _getBeacon();
    }

    /// @notice Returns the address of the installed logic contract for the proxy
    function getImplementation() public view returns (address) {
        return _implementation();
    }

    /// @notice Returns the description of the proxy
    function getProxyDescription() external pure returns (string memory) {
        return "Second proxy";
    }

    receive() external payable {}
}
