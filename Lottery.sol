// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";

contract Lottery is Ownable{
    string name = "Snow Lottery";
    
    struct LotteryData {
        uint256 id;
        uint256 ticketPrice;
        uint256 totalTickets;
        uint256 ticketsSold;
        uint256 ticketId;
        bool closed;
        bool exists;
        address payable owner;
    }

    struct Ticket {
        uint256 id;
        uint256 lotteryId;
        address payable owner;
    }

    mapping (uint256 => LotteryData) public lotteries;
    mapping (uint256 => mapping (uint256 => address payable)) public ticketOwners; // Mapping from lottery ID to mapping of ticket ID to ticket owner address
    mapping (uint256 => address) public lotteryWinners; // Mapping from lottery ID to winner address
    mapping (uint256 => uint256) public paidOut; // Mapping from lottery ID to amount paid out

    uint256 public lotteryCounter;

    event LotteryCreated(uint256 indexed id, uint256 ticketPrice, uint256 totalTickets);
    event LotteryTicketPurchased(uint256 indexed lotteryId, uint256 indexed ticketId, address indexed buyer);

    modifier lotteryExists(uint256 _lotteryId) {
        require(lotteries[_lotteryId].exists, "Lottery does not exist.");
        _;
    }

    constructor() {
        lotteryCounter = 0;
    }

    function createLottery(uint256 _ticketPrice, uint256 _totalTickets) external onlyOwner {
        lotteryCounter++;
        lotteries[lotteryCounter] = LotteryData(lotteryCounter, _ticketPrice, _totalTickets, 0, 0, false, true, payable(msg.sender));
        emit LotteryCreated(lotteryCounter, _ticketPrice, _totalTickets);
    }

    function buyTickets(uint256 _lotteryId, uint256 _amount) external payable lotteryExists(_lotteryId) {
        LotteryData storage lottery = lotteries[_lotteryId];
        require(!lottery.closed, "Lottery is closed.");
        require(msg.value == lottery.ticketPrice * _amount, "Incorrect amount of ether sent.");
        require(lottery.totalTickets >= _amount, "Not enough tickets available.");

        uint256 currentTicketId = lottery.ticketId;

        for (uint256 i = 0; i < _amount; i++) {
            lottery.totalTickets--;
            lottery.ticketsSold++;
            ticketOwners[_lotteryId][currentTicketId] = payable(msg.sender);
            currentTicketId++;

            emit LotteryTicketPurchased(_lotteryId, currentTicketId, msg.sender);
        }

        lottery.ticketId = currentTicketId;
    }

    function closeLottery(uint256 _lotteryId) external onlyOwner lotteryExists(_lotteryId) {
        LotteryData storage lottery = lotteries[_lotteryId];
        require(!lottery.closed, "Lottery is already closed.");
        uint _balancecontract = address(this).balance;
        require(_balancecontract > 0, "No funds in contract.");

        uint256 winningTicketId = generateRandomNumber(_lotteryId, lottery.ticketsSold);
        address payable winner = ticketOwners[_lotteryId][winningTicketId];
        uint prize = _balancecontract * 97 / 100;
        
        lotteryWinners[_lotteryId] = winner;
        lottery.closed = true;

        winner.transfer(prize);
        payable(owner()).transfer(_balancecontract - prize);

        paidOut[_lotteryId] = prize;
    }

    function generateRandomNumber(uint256 _seed, uint256 _modulus) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, _seed))) % _modulus;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
