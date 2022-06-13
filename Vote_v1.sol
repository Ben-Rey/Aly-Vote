// SPDX-License-Identifier: MIT
// TODO - Handle equality
// TODO - essayer de faire des sessions mapping de mapping : Factory ?

// TODO - Option anonyme
// TODO - Utiliser systeme de role

pragma solidity 0.8.14;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/// @author Alyra Student
/// @title Voting System
contract VotingSystem is Ownable {
    uint256 winningProposalId;
    bool isWinnigProposal;
    bool firstVote;

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint256 votedProposalId;
    }

    struct Proposal {
        string description;
        uint256 voteCount;
    }

    struct Session {
        uint256 winningProposalId;
        uint256 endOfSession;
    }

    enum WorkflowStatus {
        RegisteringVoters, // 0
        ProposalsRegistrationStarted, // 1
        ProposalsRegistrationEnded, // 2
        VotingSessionStarted, // 3
        VotingSessionEnded, // 4
        VotesTallied // 5
    }

    Session[] history;
    mapping(address => Voter) public addressToVoter;

    address[] public voters;
    WorkflowStatus public status;
    Proposal[] proposals;

    event VoterRegistered(address voterAddress);
    event ProposalRegistered(uint256 proposalId);
    event Voted(address voter, uint256 proposalId);
    event WorkflowStatusChange(
        WorkflowStatus previousStatus,
        WorkflowStatus newStatus
    );

    constructor() {
        // Allow blank vote
        proposals.push(Proposal("Vote Null", 0));
        proposals.push(Proposal("Vote Blanc", 1));
        //Test
        registerVoter(address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2));
        registerVoter(address(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db));
        registerVoter(address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4));
        registerVoter(address(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB));

        proposals.push(Proposal("Proposal 1", 4));
        proposals.push(Proposal("Proposal 2", 2));
        proposals.push(Proposal("Proposal 3", 1));
        proposals.push(Proposal("Proposal 4", 1));
        proposals.push(Proposal("Proposal 5", 1));
        firstVote = true;
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
        if (status == WorkflowStatus.VotingSessionEnded) {
            calculateWinnner();
        }
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

        proposals.push(Proposal(_description, 0));
        emit ProposalRegistered(proposals.length - 1);
    }

    function vote(uint256 _proposalId)
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

    function calculateWinnner() private {
        require(firstVote, "No one voted");
        require(!isWinnigProposal, "Calcul already done");
        uint256 bestscore;
        uint256 winnerId;

        for (uint256 i; i < proposals.length; i++) {
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

    function resetVotingSystem() external onlyOwner {
        status = WorkflowStatus(0);
        history.push(Session(winningProposalId, block.timestamp));

        for (uint256 i = 0; i < voters.length - 1; i++) {
            addressToVoter[voters[i]] = Voter(false, false, 0);
        }

        delete voters;
        delete proposals;
        // Add proposal temp to save gas ?
        proposals.push(Proposal("Vote Null", 0));
        proposals.push(Proposal("Vote Blanc", 0));
        isWinnigProposal = false;
    }
}