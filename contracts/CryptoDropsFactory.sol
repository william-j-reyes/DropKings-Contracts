// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CryptoDrops.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract GiveawayFactory is VRFConsumerBaseV2{
    VRFCoordinatorV2Interface COORDINATOR;
    address vrfCoordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;
    bytes32 keyHash = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;
    // address vrfCoordinator = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;
    // bytes32 keyHash = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
    uint32 callbackGasLimit = 1000000;
    uint16 requestConfirmations = 3;
    uint32 numWords =  1;
    uint256[] public s_randomWords;
    uint256 public s_requestId;

    address public owner;
    address[] public deployedGiveaways;
    uint256 public totalTips;
    uint256 public totalPrize;

    uint64 public s_subscriptionId;
    uint64[] public subscriptions;
    address private _cur;

    event NewParticipant(address indexed _owner, address indexed _contract, string _title, uint _entryTime, uint256 _prize);
    event NewGiveaway(address indexed _owner, address indexed _contract, string _title, uint _expiry, uint256 _prize);
    event NewWinner(address indexed _winner, address indexed _contract, string _title, uint _date, uint256 _prize);
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    constructor() VRFConsumerBaseV2(vrfCoordinator){
        owner = msg.sender;
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        createNewSubscription();
    }

    function createNewSubscription() public onlyOwner {
        s_subscriptionId = COORDINATOR.createSubscription();
        subscriptions.push(s_subscriptionId);
        COORDINATOR.addConsumer(s_subscriptionId, address(this));
    }

    function cancelSubscription(uint64 sid, address receivingWallet) external onlyOwner {
        COORDINATOR.cancelSubscription(sid, receivingWallet);
    }

          // Assumes the subscription is funded sufficiently.
    function requestRandomWords() private {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );
    }

    function fulfillRandomWords( uint256, /* requestId */uint256[] memory randomWords
    ) internal override {
        // Callback function... takes while to complete
        s_randomWords = randomWords;
        Giveaway g = Giveaway(_cur);
        g.selectWinner(randomWords[0]);
        emit NewWinner(g.winner(), _cur, g.title(), block.timestamp, g.prizePool());
    }

    function createGiveaway( string memory _title, uint256 expiry, uint256 _tip, string memory _description) public payable{
        require(msg.value - _tip > 0, "Cannot Create Giveaway without Prize");
        Giveaway GA = new Giveaway{value: msg.value - _tip}(address(this) ,msg.sender, _title, expiry, _description);
        totalPrize += msg.value - _tip;
        // Tip the hatter
        payable(owner).transfer(_tip);
        totalTips +=  _tip;
        // Add to array and map
        deployedGiveaways.push(address(GA));
        // Emit new creation event
        // Add this contract as a consumer of its own subscription.
        emit NewGiveaway(msg.sender, address(GA), _title, expiry, msg.value - _tip);
    }

    function getDeployedGiveaways() public view returns(address[] memory){ 
        return deployedGiveaways;
    }

    function getSlicedGifts(uint256 start, uint256 end) public view returns(address[] memory){ 
        require(end <= deployedGiveaways.length, "End index is too large");
        require(start >= 0 && end > 0, "Start and End Index must be Positive");
        require(start < end, "Start index must be smaller than End index");
        address[] memory gifts = new address[](end - start);
        uint256 index = 0;

        while(start < end){
            gifts[index] = deployedGiveaways[start];
            index ++;
            start ++;
        }
        return gifts;
    }

    function totalGiveaways() public view
            returns (uint256 totalGiveAways_)
    {
        totalGiveAways_ = deployedGiveaways.length;
    }

    function enterFreeGiveaway(address _address) public
    {
        Giveaway g = Giveaway(_address);
        g.enterFreeGiveaway(msg.sender);
        // Emit NewParticipant Event
        emit NewParticipant(msg.sender, _address, g.title(), block.timestamp, g.prizePool());
    }

    function selectWinner(address _contractAddress) public
    {
        Giveaway g = Giveaway(_contractAddress);
        require(g.owner() == msg.sender || owner == msg.sender , "Only giveaway owner can call this function");
        require(g.totalEntries() > 0, "Atleast 1 person is entered");
        require(g.winner() == address(0), "Winner hasn't been selected");
        _cur = _contractAddress;
        requestRandomWords();
    }

}