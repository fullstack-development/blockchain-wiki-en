// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PluginUUPSUpgradeable, IDAO} from "@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWETH} from "src/interfaces/IWETH.sol";

contract WETHPlugin is PluginUUPSUpgradeable {
    /// @notice Permission to call the deposit() function
    bytes32 public constant DEPOSIT_PERMISSION = keccak256("DEPOSIT_PERMISSION");

    IWETH internal _weth;
    IDAO internal _dao;

    /// @notice Performs the initialization of the plugin
    function initialize(IDAO dao, IWETH weth) external initializer {
        __PluginUUPSUpgradeable_init(dao);

        _weth = weth;
        _dao = dao;
    }

    /// @notice Wraps ETH into WETH
    function depositToWeth() external payable auth(DEPOSIT_PERMISSION) {
        _weth.deposit{value: msg.value}();
        IERC20(address(_weth)).transfer(address(_dao), msg.value);
    }
}
