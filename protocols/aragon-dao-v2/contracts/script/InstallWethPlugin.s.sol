// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {TokenVoting} from "@aragon/osx/plugins/governance/majority-voting/token/TokenVoting.sol";
import {PluginSetupRef, hashHelpers} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessorHelpers.sol";
import {PluginRepoFactory, PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepoFactory.sol";
import {IMajorityVoting} from "@aragon/osx/plugins/governance/majority-voting/IMajorityVoting.sol";
import {PluginSetupProcessor} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessor.sol";
import {IPluginSetup} from "@aragon/osx/framework/plugin/setup/IPluginSetup.sol";
import {PermissionManager} from "@aragon/osx/core/permission/PermissionManager.sol";
import {DAO, IDAO} from "@aragon/osx/core/dao/DAO.sol";

import {WETHPluginSetup} from "src/WETHPluginSetup.sol";

contract InstallWethPlugin is Script {
    /// Here, you need to change: DEPLOYER_ADDRESS, DAO_ADDRESS.
    address constant DEPLOYER_ADDRESS = 0x32bb35Fc246CB3979c4Df996F18366C6c753c29c;
    address constant DAO_ADDRESS = 0x201836b4AEE703f29913c4b5CEb7E1c16C5eAb7b;

    address constant PLUGIN_REPO_FACTORY = 0x07f49c49Ce2A99CF7C28F66673d406386BDD8Ff4;
    address constant PLUGIN_SETUP_PROCESSOR = 0xC24188a73dc09aA7C721f96Ad8857B469C01dC9f;
    address constant WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address constant TOKEN_VOTING = 0xAABcB955DC1Ab7fDE229944DD329b4efc10c4ca7;

    /// We use pluginRepoFactory and pluginSetupProcessor on the Sepolia network
    PluginRepoFactory pluginRepoFactory = PluginRepoFactory(PLUGIN_REPO_FACTORY);
    PluginSetupProcessor pluginSetupProcessor = PluginSetupProcessor(PLUGIN_SETUP_PROCESSOR);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        /// Step 1 - Deploy the smart contract with the configurations for plugin installation
        WETHPluginSetup pluginSetupAddress = new WETHPluginSetup();

        /// Step 2 - Create and register the PluginRepo
        /// 2.1 Subdomain for plugin registration in ENS
        string memory subdomain = "weth-plugin";
        /// 2.2 Metadata (cannot pass bytes(0)).
        bytes memory releaseMetadata = new bytes(1);
        bytes memory buildMetadata = new bytes(1);
        /// 2.3 Deploy and register the PluginRepo.
        PluginRepo pluginRepo = pluginRepoFactory.createPluginRepoWithFirstVersion(
            subdomain, address(pluginSetupAddress), DEPLOYER_ADDRESS, releaseMetadata, buildMetadata
        );

        /// Step 3 - Submit a request to install the plugin in our DAO
        /// To do this, the parameters need to be prepared
        /// 3.1 Plugin version and PluginRepo address
        PluginSetupRef memory pluginSetupRef =
            PluginSetupRef(PluginRepo.Tag({release: uint8(1), build: uint16(1)}), pluginRepo);

        /// 3.2 Data required for plugin installation
        bytes memory payload = abi.encode(WETH);

        /// 3.3 Prepare the final parameters
        PluginSetupProcessor.PrepareInstallationParams memory prepareInstallationParams =
            PluginSetupProcessor.PrepareInstallationParams(pluginSetupRef, payload);

        /// 3.4 Perform pre-installation (this is only the first stage of the installation)
        (address plugin, IPluginSetup.PreparedSetupData memory preparedSetupData) =
            pluginSetupProcessor.prepareInstallation(DAO_ADDRESS, prepareInstallationParams);

        /// Step 4 - Prepare for the final plugin installation
        /// 4.1 Helpers are not needed, so create an empty array
        address[] memory helpers = new address[](0);

        /// 4.2 Set the installation parameters
        /// The plugin address was obtained during pre-installation, as it was deployed via prepareInstallation
        /// pluginSetupRef has already been prepared earlier
        /// Permissions are used from WETHPluginSetup
        PluginSetupProcessor.ApplyInstallationParams memory applyInstallationParams = PluginSetupProcessor
            .ApplyInstallationParams({
            pluginSetupRef: pluginSetupRef,
            plugin: plugin,
            permissions: preparedSetupData.permissions,
            helpersHash: hashHelpers(helpers)
        });

        /// Step 5 - Since only the DAO can perform the installation, and the `DAO::execute()` function can be called
        /// only through the TokenVoting app, a vote must be created for these actions

        /// 5.1 Get the instance of the TokenVoting app
        TokenVoting tokenVoting = TokenVoting(TOKEN_VOTING);

        /// 5.2 Prepare an array of Actions that will be submitted for execution by the DAO
        /// In addition to directly installing the WETHPlugin
        /// Grant the ROOT_PERMISSION_ID permission to the PluginSetupProcessor contract
        /// So that it can grant permissions from WETHPluginSetup
        /// Afterwards, this permission must be revoked
        IDAO.Action[] memory actions = new IDAO.Action[](3);
        
        /// Action to grant the ROOT_PERMISSION_ID permission to PluginSetupProcessor
        actions[0] = IDAO.Action({
            to: address(DAO_ADDRESS),
            value: 0,
            data: abi.encodeCall(
                PermissionManager.grant,
                (DAO_ADDRESS, address(pluginSetupProcessor), DAO(payable(DAO_ADDRESS)).ROOT_PERMISSION_ID())
            )
        });
        /// Action to install the plugin
        actions[1] = IDAO.Action({
            to: address(pluginSetupProcessor),
            value: 0,
            data: abi.encodeCall(PluginSetupProcessor.applyInstallation, (DAO_ADDRESS, applyInstallationParams))
        });
        /// Action to revoke the ROOT_PERMISSION_ID permission from PluginSetupProcessor
        actions[2] = IDAO.Action({
            to: address(DAO_ADDRESS),
            value: 0,
            data: abi.encodeCall(
                PermissionManager.revoke,
                (DAO_ADDRESS, address(pluginSetupProcessor), DAO(payable(DAO_ADDRESS)).ROOT_PERMISSION_ID())
            )
        });
        
        /// 5.3 Create a proposal for voting
        bytes memory metadata = new bytes(0);
        uint256 proposalId =
            tokenVoting.createProposal(metadata, actions, 0, 0, 0, IMajorityVoting.VoteOption.None, false);

        /// Step 6 - Vote on the proposal (since we are the only holders of voting tokens)
        tokenVoting.vote(proposalId, IMajorityVoting.VoteOption.Yes, false);

        /// Step 7 - Execute the proposal (only at this step will the plugin be installed)
        tokenVoting.execute(proposalId);

        vm.stopBroadcast();

        console.log("------------------ Deployed contracts --------------------");
        console.log("WethPlugin        : ", plugin);
        console.log("WETHPluginSetup   : ", address(pluginSetupAddress));
        console.log("WethPluginRepo    : ", address(pluginRepo));
        console.log("------------------ Deployment info -----------------------");
        console.log("Chain id           : ", block.chainid);
        console.log("Deployer          : ", vm.addr(deployerPrivateKey));
    }
}
