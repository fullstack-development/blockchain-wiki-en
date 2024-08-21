// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PluginSetup, IPluginSetup} from "@aragon/osx/framework/plugin/setup/PluginSetup.sol";
import {PermissionLib} from "@aragon/osx/core/permission/PermissionLib.sol";
import {WETHPlugin, IDAO, IWETH} from "src/WETHPlugin.sol";

contract WETHPluginSetup is PluginSetup {
    /// @notice Адрес плагина
    address private immutable wethPlugin;

    /// @notice Reverts if the WETH address is not provided
    error WethAddressInvalid();

    /// @dev The PluginSetup contract is deployed only once for the plugin
    constructor() {
        wethPlugin = address(new WETHPlugin());
    }

    /// @inheritdoc IPluginSetup
    function prepareInstallation(address _dao, bytes calldata _data)
        external
        returns (address plugin, PreparedSetupData memory preparedSetupData)
    {
        /// Retrieve the WETH address from the data provided during installation
        IWETH weth = abi.decode(_data, (IWETH));

        /// Verify that the address is valid
        if (address(weth) == address(0)) {
            revert WethAddressInvalid();
        }

        /// Create a proxy for the WETHPlugin
        plugin = createERC1967Proxy(wethPlugin, abi.encodeCall(WETHPlugin.initialize, (IDAO(_dao), weth)));

        /// Grant permission for the DAO to call the deposit() function
        PermissionLib.MultiTargetPermission[] memory permissions = new PermissionLib.MultiTargetPermission[](1);

        permissions[0] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Grant,
            where: plugin,
            who: _dao,
            condition: PermissionLib.NO_CONDITION,
            permissionId: WETHPlugin(this.implementation()).DEPOSIT_PERMISSION()
        });

        preparedSetupData.permissions = permissions;
    }

    /// @inheritdoc IPluginSetup
    function prepareUninstallation(address _dao, SetupPayload calldata _payload)
        external
        view
        returns (PermissionLib.MultiTargetPermission[] memory permissions)
    {
        /// Revoke permission for the DAO to call the deposit() function
        permissions = new PermissionLib.MultiTargetPermission[](1);

        permissions[0] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Revoke,
            where: _payload.plugin,
            who: _dao,
            condition: PermissionLib.NO_CONDITION,
            permissionId: WETHPlugin(this.implementation()).DEPOSIT_PERMISSION()
        });
    }

    /// @inheritdoc IPluginSetup
    function implementation() external view returns (address) {
        return wethPlugin;
    }
}
