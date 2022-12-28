// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Giveaway{

    address public parent;
    address public owner;
    uint256 public prizePool;
    bool  public open;
    uint256 public totalEntries;
    uint256 public closingTime;
    address public winner;
    string public title;
    string public description;
    
    constructor (address _parent, address deployer, string memory _title, uint256 expiry, string memory _description) payable {
        parent = _parent;
        owner = deployer;
        open = true;
        totalEntries = 0;
        closingTime = expiry;
        prizePool = msg.value;
        title = _title;
        description = _description;
    }
   
    struct Participant {
        address owner; // Address of person entering the giveaway
        uint256 entries; // Number of tickets entered in the giveaway
        uint entryTime; // Date time user entered giveaway
    }

    struct Variables{
        address  owner;
        uint256  prizePool;
        bool   open;
        uint256  totalEntries;
        uint256  closingTime;
        address  winner;
        string  title;
        string description;
    }

    mapping(address => bool) public entryStatus;
    mapping(address => Participant) public entryInfo;
    Participant[] public participants;

    modifier isParent(){
        require(msg.sender == parent, "Only the Parent contract can use this function");
        _;
    }

    modifier isOwner(){
        require(msg.sender == owner, "Only the owner can use this function");
        _;
    }

    modifier isOpen(){
        require(open, "Giveaway must be open");
        require(winner == address(0), "No winner has been selected");
        _;
    }

    // Function to Enter the giveaway
    function enterFreeGiveaway(address _address) isOpen isParent public {
        require(_address != address(0), "Address 0 cannot enter");
        require(!entryStatus[_address], "You can only enter the free giveaway once");
        // Create new participant
        Participant memory newEntry = Participant(_address, 1, block.timestamp);
        // Append to array of participants
        participants.push(newEntry);
        entryInfo[_address] = newEntry;
        // Change entryStatus to True
        entryStatus[_address] = true;
        // Increase number of entries and participants
        totalEntries ++;
    } 

    // Function to select the winner
    function selectWinner(uint256 seed) isParent isOpen public {
        // Generate Random 
        uint256 random = seed % participants.length;
        winner = participants[random].owner;
        open = false;
        payWinner();
    }

    function payWinner() internal {
        require(address(this).balance == prizePool, "Contract has a balance");
        require(winner != address(0), "Winner must be chosen");
        // Transfer the prizePool to the winner
        payable(winner).transfer(prizePool);
    }

    function refund() isOwner isOpen public payable{
        // Empty the prizepool and send back to owner
        payable(msg.sender).transfer(prizePool);
        prizePool = 0;
        // Close the giveaway
        open = false;
    }

    /** 
     * @return totalParticipants_ The number of participants in the giveaway
     */
    function totalParticipants() public view
            returns (uint256 totalParticipants_)
    {
        totalParticipants_ = participants.length;
    }

    function getParticipants() public view
            returns (Participant[] memory getParticipants_)
    {
        getParticipants_ = participants;
    }

    function getGiveaway() public view returns(Variables memory variables_ ){
        variables_= Variables(owner, prizePool, open, totalEntries, closingTime, winner, title, description);
        return variables_;
    }
}