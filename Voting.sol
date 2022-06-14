// SPDX-License-Identifier: MIT
// TODO si egalité on revote pour désigner le gagnant

pragma solidity 0.8.14;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/// @author Alyra Student
/// @title Voting System
contract VotingSystem is Ownable {

    // Struct
    // Allow to store address while keeping the integrity of Voter
    struct VoterWrapper {
        address voterAddress;
        Voter voterInfo;
    }

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint256 votedProposalId;
    }

    struct Proposal {
        string description;
        uint256 voteCount;
    }

    // Enum to handle different status in the voting workflow
    enum WorkflowStatus {
        RegisteringVoters, // 0
        ProposalsRegistrationStarted, // 1
        ProposalsRegistrationEnded, // 2
        VotingSessionStarted, // 3
        VotingSessionEnded, // 4
        VotesTallied // 5
    }

    // Variables
    // Array of winners (in case of equality)
    uint256[] winningProposalIds;
    VoterWrapper[] public voters;
    WorkflowStatus public status;
    Proposal[] proposals;

    // Session
    struct Session {
        uint256[] winningProposalIds;
        uint256 endOfSession;
    }
    mapping(uint256 => mapping(uint256 => Proposal)) proposalHistory;
    Session[] sessionHistory;

    // Events
    event VoterRegistered(address voterAddress);
    event ProposalRegistered(uint256 proposalId);
    event Voted(address voter, uint256 proposalId);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);

    function isVoterInList(address _address) private view returns (bool inList) {
        for (uint256 i; i < voters.length; i++) {
            if (voters[i].voterAddress == _address) {
                if (voters[i].voterInfo.isRegistered) {
                    return true;
                }
                return false;
            }
        }
    }

    // Modifiers
    modifier voterIsRegistered(uint _voterIndex) {
        //require(isVoterInList(msg.sender), "Voter not registered");
        require(_voterIndex < voters.length, "This voter doesn't exist");
        require(voters[_voterIndex].voterAddress == msg.sender, "You can't vote for someone else");
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
    function getPoroposals() external view afterStatus(WorkflowStatus.ProposalsRegistrationStarted) returns (Proposal[] memory) {
        return proposals;
    }

    function getVoters() external view returns (VoterWrapper[] memory) {
        return voters;
    }

    /**
     * @notice Get a registered proposal
     * @dev Get a Proposal by is Id
     * @param index (uint) in the proposals array
     * @return a Proposal object
     */
    function getProposalById(uint256 index) external view returns (Proposal memory) {
        require(index < proposals.length, "Out of range");
        return proposals[index];
    }

    /**
     * @notice Register a Voter
     * @dev Register a Voter by his address
     * @param _address (address)
     */
    function registerVoter(address _address) public onlyOwner inStatus(WorkflowStatus.RegisteringVoters) {
        require(_address != address(0));
        require(!isVoterInList(_address), "The Voter is already registered");

        voters.push(VoterWrapper(_address, Voter(true, false, 0)));
        emit VoterRegistered(_address);
    }

    // Private function that check if a proposal exist
    function proposalExist(string calldata _proposalDescription) private view returns (bool) {
        for (uint256 i; i < proposals.length; i++) {
            if (keccak256(abi.encodePacked((proposals[i].description))) == keccak256(abi.encodePacked((_proposalDescription)))) {
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
        if (status == WorkflowStatus.RegisteringVoters) {
            // Allow blank vote
            proposals.push(Proposal("Vote Null", 0));
            proposals.push(Proposal("Vote Blanc", 0));
        }
        WorkflowStatus prevStatus = status;
        status = WorkflowStatus(uint256(status) + 1);
        emit WorkflowStatusChange(prevStatus, status);
    }


    function propose(string calldata _description, uint _voterIndex) external inStatus(WorkflowStatus.ProposalsRegistrationStarted) voterIsRegistered(_voterIndex) {
        require(bytes(_description).length > 0, "You have to provide a description");
        require(!proposalExist(_description), "This porposal already exist");

        proposals.push(Proposal(_description, 0));
        emit ProposalRegistered(proposals.length - 1);
    }

    function vote(uint256 _proposalId, uint256 _voterIndex) external inStatus(WorkflowStatus.VotingSessionStarted) voterIsRegistered(_voterIndex) {
        require(voters[_voterIndex].voterInfo.hasVoted == false, "You already voted");
        require(_proposalId < proposals.length, "This proposal does not exist");

        voters[_voterIndex].voterInfo.votedProposalId = _proposalId;
        voters[_voterIndex].voterInfo.hasVoted = true;
        proposals[_proposalId].voteCount++;
        emit Voted(msg.sender, _proposalId);
    }

    function calculateWinnner() private {
        uint256 bestscore;
        uint256[] memory winnerIds = new uint256[](proposals.length);
        uint256 counter;

        for (uint256 i; i < proposals.length; i++) {
            if (proposals[i].voteCount > bestscore) {
                counter = 0;
                winnerIds = new uint256[](proposals.length);
                winnerIds[counter] = i;
                bestscore = proposals[i].voteCount;
                counter++;
            } else if (proposals[i].voteCount == bestscore) {
                winnerIds[counter] = i;
                counter++;
            }
        }

        uint256[] memory tempWinners = new uint256[](counter);

        // Remove zero from Array
        for (uint256 i; i < winnerIds.length; i++) {
            if (winnerIds[i] == 0) {
                break;
            }
            tempWinners[i] = winnerIds[i];
        }

        if (winningProposalIds.length == 0) {
            tempWinners[0] = 0;
        }

        winningProposalIds = tempWinners;
    }

    // Getter to keep winningProposalIds variable private and only access it when status = VotesTallied
    function getWinnerIds() external view inStatus(WorkflowStatus.VotesTallied) returns (uint256[] memory) {
        return winningProposalIds;
    }

    // Get the winners of an old session
    function OldSessionWinner(uint256 _sessionId) external view returns (Proposal[] memory) {
        require(sessionHistory.length > 0, "No history yet");
        require(_sessionId < sessionHistory.length, "No history at this index");

        uint proposalLenght = sessionHistory[_sessionId].winningProposalIds.length;
        
        Proposal[] memory winnerProposals = new Proposal[](proposalLenght);

        for (uint256 i = 0; i < proposalLenght; i++) {
            winnerProposals[i] = proposalHistory[_sessionId][sessionHistory[_sessionId].winningProposalIds[i]];
        }
        return winnerProposals;
    }
    
    // Reset the votung system and allow to keep history
    function resetVotingSystem(bool _saveSession) external onlyOwner inStatus(WorkflowStatus.VotesTallied) {
        status = WorkflowStatus(0);
        // Save session in history
        if (_saveSession) {
            sessionHistory.push(Session(winningProposalIds, block.timestamp));
            for (uint256 i = 0; i < proposals.length - 1; i++) {
                proposalHistory[sessionHistory.length - 1][i] = proposals[i];
            }
        }

        delete voters;
        delete proposals;
        delete winningProposalIds;
    }
}
