// SPDX-License-Identifier: MIT
// Comment why you choose to do it like this

// TODO - essayer de faire des sessions mapping de mapping : Factory ?
// TODO - Option anonyme
// Handle equality

// TODO - L'admin peut etre corrompu
// TODO - Utiliser systeme de role

// TOCHECK - all functions are well securized
// TOCHECK - Reduce uint

pragma solidity 0.8.14;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/// @author Alyra Student
/// @title Voting System
contract VotingSystem is Ownable {
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint16 votedProposalId;
    }

    struct Proposal {
        string description;
        uint32 voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters, // 0
        ProposalsRegistrationStarted, // 1
        ProposalsRegistrationEnded, // 2
        VotingSessionStarted, // 3
        VotingSessionEnded, // 4
        VotesTallied // 5
    }

    mapping(address => Voter) public addressToVoter;
    address[] public voters;
    WorkflowStatus public status;
    Proposal[] proposals;

    uint16 winningProposalId;
    bool isWinnigProposal;
    bool firstVote;

    event VoterRegistered(address voterAddress);
    event ProposalRegistered(uint16 proposalId);
    event Voted(address voter, uint16 proposalId);
    event WorkflowStatusChange(
        WorkflowStatus previousStatus,
        WorkflowStatus newStatus
    );

    constructor() {
        // Allow blank vote
        proposals.push(Proposal("Vote Null", 0));
        proposals.push(Proposal("Vote Blanc", 1));
    }

    function isVoterInList(address _address)
        private
        view
        returns (bool inList)
    {
        for (uint256 i; i < voters.length; i++) {
            if (voters[i] == _address) {
                return true;
            }
        }
    }

    modifier voterIsRegistered() {
        require(isVoterInList(msg.sender), "Voter not registered");
        require(
            addressToVoter[msg.sender].isRegistered,
            "Voter not registered"
        );
        _;
    }

    modifier inStatus(WorkflowStatus _status) {
        require(status == _status, "Action not allowed in this status");
        _;
    }

    modifier afterStatus(WorkflowStatus _status) {
        require(status >= _status, "Action not allowed in this status");
        _;
    }

    /**
     * @notice Get the proposal list if the Proposal registration strated
     * @return an Arrays of Proposals or an empty Array
     */
    function getPoroposals()
        external
        view
        afterStatus(WorkflowStatus.ProposalsRegistrationStarted)
        returns (Proposal[] memory)
    {
        return proposals;
    }

    /**
     * @notice Get a registered proposal
     * @dev Get a Proposal by is Id
     * @param index (uint) in the proposals array
     * @return a Proposal object
     */
    function getProposalById(uint256 index)
        external
        view
        returns (Proposal memory)
    {
        require(index < proposals.length, "Out of range");
        return proposals[index];
    }

    function registerVoter(address _address)
        public
        onlyOwner
        inStatus(WorkflowStatus.RegisteringVoters)
    {
        require(_address != address(0));
        require(!isVoterInList(_address), "The Voter is already registered");

        addressToVoter[_address] = Voter(true, false, 0);
        voters.push(_address);
        emit VoterRegistered(_address);
    }

    function proposalExist(string calldata _proposalDescription)
        private
        view
        returns (bool)
    {
        for (uint256 i; i < proposals.length; i++) {
            if (
                keccak256(abi.encodePacked((proposals[i].description))) ==
                keccak256(abi.encodePacked((_proposalDescription)))
            ) {
                return true;
            }
        }
        return false;
    }

    /// @notice Change the status to the next (only owner function)
    function nextStatus() external onlyOwner {
        require(uint256(status) < 5, "No status left");
        WorkflowStatus prevStatus = status;
        status = WorkflowStatus(uint256(status) + 1);
        emit WorkflowStatusChange(prevStatus, status);
    }

    function propose(string calldata _description)
        external
        inStatus(WorkflowStatus.ProposalsRegistrationStarted)
        voterIsRegistered
    {
        require(
            bytes(_description).length > 0,
            "You have to provide a description"
        );
        require(!proposalExist(_description), "This porposal already exist");
        require(proposals.length <= type(uint16).max, "Too much proposals");

        proposals.push(Proposal(_description, 0));
        emit ProposalRegistered(uint16(proposals.length) - 1);
    }

    function vote(uint16 _proposalId)
        external
        inStatus(WorkflowStatus.VotingSessionStarted)
        voterIsRegistered
    {
        require(
            addressToVoter[msg.sender].hasVoted == false,
            "You already voted"
        );
        require(_proposalId < proposals.length, "This proposal does not exist");

        addressToVoter[msg.sender].votedProposalId = _proposalId;
        addressToVoter[msg.sender].hasVoted = true;
        proposals[_proposalId].voteCount++;
        if (!firstVote) {
            firstVote = true;
        }
        emit Voted(msg.sender, _proposalId);
    }

    function calculateWinnner()
        external
        onlyOwner
        afterStatus(WorkflowStatus.VotingSessionEnded)
    {
        require(firstVote, "No one voted");
        require(!isWinnigProposal, "Calcul already done");
        uint256 bestscore;
        uint16 winnerId;

        for (uint16 i; i < proposals.length; i++) {
            if (proposals[i].voteCount > bestscore) {
                bestscore = proposals[i].voteCount;
                winnerId = i;
            }
        }

        winningProposalId = winnerId;
        isWinnigProposal = true;
    }

    function getWinnerId()
        external
        view
        inStatus(WorkflowStatus.VotesTallied)
        returns (uint256)
    {
        require(isWinnigProposal, "The winner has not been chosen yet");
        return winningProposalId;
    }

    function resetVotingSystem() public onlyOwner {
        status = WorkflowStatus(0);

        for (uint256 i = 0; i < voters.length - 1; i++) {
            addressToVoter[voters[i]].isRegistered = false;
            addressToVoter[voters[i]].hasVoted = false;
            addressToVoter[voters[i]].votedProposalId = 0;
        }

        delete voters;
        delete proposals;
        // Add proposal temp to save gas ?
        proposals.push(Proposal("Vote Null", 0));
        proposals.push(Proposal("Vote Blanc", 1));
        isWinnigProposal = false;
    }
}
