// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/// logic smart contract
contract Logic is UUPSUpgradeable, OwnableUpgradeable {
    uint256 private _value;

    /**
     * @dev Since upgradeable contracts do not have a constructor, we need to use the `initialize()` function
     * Additionally, it is necessary to initialize the OwnableUpgradeable contract, as it is also upgradeable
     * The address _initialOwner will become the owner of the Logic contract and will be able to update the implementation for the proxy
     */
    function initialize(address _initialOwner) external initializer {
       __Ownable_init(_initialOwner);
    }

    function store(uint256 _newValue) public {
        _value = _newValue;
    }

    function retrieve() public view returns (uint256) {
        return _value;
    }

    /**
     * @notice Check if the contract can be updated
     * @dev According to the abstract UUPSUpgradeable contract, we must override this function
     * Using our own implementation of the function, we will determine the ability to update the logic contract for the proxy
     * In this example, only the owner of the logic contract can update the logic contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

/// proxy contract
contract LogicProxy is ERC1967Proxy {
    constructor(
        address _logic,
        bytes memory _data
    ) ERC1967Proxy(_logic, _data) {}

    /// @notice Возвращает адрес установленного контракта логики для прокси
    function getImplementation() public view returns (address) {
        return _implementation();
    }

    receive() external payable {}
}
