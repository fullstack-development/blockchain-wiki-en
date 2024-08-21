// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {TokenVoting} from "@aragon/osx/plugins/governance/majority-voting/token/TokenVoting.sol";
import {IMajorityVoting} from "@aragon/osx/plugins/governance/majority-voting/IMajorityVoting.sol";
import {IDAO} from "@aragon/osx/core/dao/DAO.sol";

import {IWETHPlugin} from "src/interfaces/IWETHPlugin.sol";
import {IWETH} from "src/interfaces/IWETH.sol";

contract DepositToWeth is Script {
    /// Here, you need to change: DEPLOYER_ADDRESS, DAO_ADDRESS, WETH_PLUGIN
    address constant DEPLOYER_ADDRESS = 0x32bb35Fc246CB3979c4Df996F18366C6c753c29c;
    address constant DAO_ADDRESS = 0x201836b4AEE703f29913c4b5CEb7E1c16C5eAb7b;
    address constant WETH_PLUGIN = 0x6602440aB337addc708cfa10077eabAEda6Cc882;

    address constant WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address constant TOKEN_VOTING = 0xAABcB955DC1Ab7fDE229944DD329b4efc10c4ca7;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        /// Step 1 - Send a small amount of ETH (0.000000000000001 ETH) to the DAO
        IDAO(DAO_ADDRESS).deposit{value: 1000}(address(0), 1000, "");

        /// Step 2 - Create a vote
        TokenVoting tokenVoting = TokenVoting(TOKEN_VOTING);

        /// 2.2 Add the action WETHPlugin::depositToWeth()
        IDAO.Action[] memory actions = new IDAO.Action[](1);

        /// Deposit 1000 wei (0.000000000000001 ETH)
        actions[0] =
            IDAO.Action({to: WETH_PLUGIN, value: 1000, data: abi.encodeCall(IWETHPlugin.depositToWeth, ())});

        /// 2.3 Create a proposal for voting
        bytes memory metadata = new bytes(0);
        uint256 proposalId =
            tokenVoting.createProposal(metadata, actions, 0, 0, 0, IMajorityVoting.VoteOption.None, false);

        /// Step 3 - Vote on the proposal
        tokenVoting.vote(proposalId, IMajorityVoting.VoteOption.Yes, false);

        /// Step 4 - Execute the proposal (since we are the only holders of voting tokens)
        tokenVoting.execute(proposalId);

        /// Step 5 - Verify the deposit; the funds should be credited to the DAO address
        uint256 wethPluginBalance = IWETH(WETH).balanceOf(DAO_ADDRESS);

        vm.stopBroadcast();

        console.log("------------------ Scrypt info --------------------");
        console.log("ProposalID        : ", proposalId);
        console.log("wethPluginBalance : ", wethPluginBalance);
        console.log("------------------ Chain info -----------------------");
        console.log("Chain id           : ", block.chainid);
    }
}
