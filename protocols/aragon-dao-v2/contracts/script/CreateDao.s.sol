// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {
    TokenVotingSetup,
    GovernanceERC20
} from "@aragon/osx/plugins/governance/majority-voting/token/TokenVotingSetup.sol";
import {MajorityVotingBase} from "@aragon/osx/plugins/governance/majority-voting/MajorityVotingBase.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";

import {IDAOFactory, DAOSettings} from "src/interfaces/IDAOFactory.sol";
import {PluginSetupRef, PluginSettings, PluginRepo} from "src/helpers/PluginRepoHelpers.sol";

contract CreateDao is Script {
    /// Here, you only need to change DEPLOYER_ADDRESS
    address constant DEPLOYER_ADDRESS = 0x32bb35Fc246CB3979c4Df996F18366C6c753c29c;

    address constant DAO_FACTORY_ADDRESS = 0x7a62da7B56fB3bfCdF70E900787010Bc4c9Ca42e;
    address constant TOKEN_VOTING_PLUGIN_REPO_ADDRESS = 0x424F4cA6FA9c24C03f2396DF0E96057eD11CF7dF;

    /// We use DAOFactory on the Sepolia network
    IDAOFactory daoFactory = IDAOFactory(DAO_FACTORY_ADDRESS);

    function run() external {
        /// Step 1 - Prepare the configurations for DAO creation

        /// 1.1 For simplicity, we will not provide detailed information about the DAO
        DAOSettings memory daoSettings =
            DAOSettings({trustedForwarder: address(0), daoURI: "", subdomain: "", metadata: new bytes(0)});

        /// Step 2 - Prepare the configurations for installing the TokenVoting plugin

        /// 2.1 Specify the version of the TokenVoting plugin and the address of the PluginRepo for this plugin (Sepolia)
        PluginSetupRef memory pluginSetupRef = PluginSetupRef(
            PluginRepo.Tag({release: uint8(1), build: uint16(2)}), PluginRepo(TOKEN_VOTING_PLUGIN_REPO_ADDRESS)
        );

        /// 2.2 Voting parameters for installing the TokenVoting plugin
        MajorityVotingBase.VotingSettings memory votingSettings = MajorityVotingBase.VotingSettings({
            votingMode: MajorityVotingBase.VotingMode.EarlyExecution, // Early execution is allowed
            supportThreshold: uint32(500000), // 50%
            minParticipation: uint32(150000), // 15%
            minDuration: uint64(86400), // 1 day
            minProposerVotingPower: 1e18 // Minimum number of tokens required for voting = 1
        });

        /// 2.3 Parameters for creating a voting token
        TokenVotingSetup.TokenSettings memory tokenSettings = TokenVotingSetup.TokenSettings({
            addr: address(0), // create new token
            name: "Test",
            symbol: "T"
        });

        /// 2.4 Token recipient — deployer address
        address[] memory receivers = new address[](1);
        receivers[0] = DEPLOYER_ADDRESS;

        /// 2.5 For example, mint 10 tokens to the deployer address
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10e18;

        /// 2.6 Parameters for the initial issuance of the voting token
        GovernanceERC20.MintSettings memory mintSettings = GovernanceERC20.MintSettings(receivers, amounts);

        /// 2.7 Finally, assemble all the plugin configurations together
        bytes memory data = abi.encode(votingSettings, tokenSettings, mintSettings);
        PluginSettings[] memory pluginSettings = new PluginSettings[](1);
        pluginSettings[0] = PluginSettings(pluginSetupRef, data);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        /// Step 3 - Create the DAO
        IDAO dao = daoFactory.createDao(daoSettings, pluginSettings);

        vm.stopBroadcast();

        console.log("------------------ Deployed contracts --------------------");
        console.log("DAO               : ", address(dao));
        console.log("------------------ Deployment info -----------------------");
        console.log("Chain id          : ", block.chainid);
        console.log("Deployer          : ", vm.addr(deployerPrivateKey));
    }
}
