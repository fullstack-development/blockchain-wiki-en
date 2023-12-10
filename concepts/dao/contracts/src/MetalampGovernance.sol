// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes, IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

/**
 * @title Metalamp voting system
 * @notice Implements the most basic voting system based on OpenZeppelin smart contracts
 * @dev Uses 4 basic extensions:
 * - GovernorSettings. For managing settings
 * - GovernorCountingSimple. For counting voting options
 * - GovernorVotes. For calculating the weight of votes
 * - GovernorVotesQuorumFraction. For managing the quorum

 */
contract MetalampGovernance is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction {
    uint48 public constant INITIAL_VOTING_DELAY = 1 days;
    uint32 public constant INITIAL_VOTING_PERIOD = 30 days;

    /// Indicates that any account is allowed to create proposals
    uint256 public constant INITIAL_PROPOSAL_THRESHOLD = 0;
    /// Indicates that the quorum value is not considered in the calculation of results
    uint256 public constant INITIAL_QUORUM_NUMERATOR_VALUE = 0;

    constructor(IVotes token)
        Governor("Metalamp governance")
        GovernorSettings(INITIAL_VOTING_DELAY, INITIAL_VOTING_PERIOD, INITIAL_PROPOSAL_THRESHOLD)
        GovernorVotes(token)
        GovernorVotesQuorumFraction(INITIAL_QUORUM_NUMERATOR_VALUE)
    {}

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }
}
