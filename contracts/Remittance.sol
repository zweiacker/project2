pragma solidity ^0.4.23;

contract Remittance {

    address public owner;
    bool pause;

    struct Transferal {
        address transferTo;
        bytes32 puzzle;
        uint value;
        uint expiry;
    }
    
    mapping (bytes32 => Transferal) public transferals;
    // bytes32[] public transferalsIndex;

    event hashHelperTX(bytes32 hashOut);
    event loaded (address beneficiary, bytes32 puzzle, uint amount);
    event unloaded (address beneficiary, bytes32 puzzle, uint amount);
    event released (address beneficiary, bytes32 puzzle, uint amount);

    constructor() public {
        owner = msg.sender;
        pause = false;
    }

    modifier isOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier isRunning() {
        require(!pause);
        _;
    }

    modifier isPaused() {
        require(pause);
        _;
    }

    function pauseContract() public isOwner isRunning {
        pause = true;
    }

    function resumeContract() public isOwner isPaused {
        pause = false;
    }

    function collect() public isPaused isOwner {
        msg.sender.transfer(address(this).balance);
    }

    function hashHelper(address a, string pw) public pure returns(bytes32) {
        bytes32 res = keccak256(a, pw);
        return res;
    }
    
    // In remix, this seems to be the only way to get hold of the return value of hashHelper
    // trying to emit (log the hash) from within hashHelper wouldn't compile
    // the txHashHelper function would not be there in production
    function txHashHelper(address a, string pw) public isRunning returns (bytes32) {
        bytes32 h = hashHelper(a, pw);
        emit hashHelperTX (h);
        return h;
    }

    function loadTransfer (address _beneficiary, bytes32 _puzzle) public isOwner isRunning payable {
        require(_beneficiary != 0);
        require(_puzzle != 0);
        require(msg.value > 0);
        require(transferals[_puzzle].transferTo == 0);

        Transferal memory newTransferal;
        newTransferal.transferTo = _beneficiary;
        newTransferal.puzzle = _puzzle;
        newTransferal.value = msg.value;
        // expiry is two minutes after creation just for testing in remix
        newTransferal.expiry = block.timestamp + 120;
        transferals[_puzzle] = newTransferal;
        emit loaded (_beneficiary, _puzzle, msg.value);
    }
    
    function unloadTransfer(address _beneficiary, bytes32 _puzzle) public isOwner isRunning {
        require(_beneficiary != 0);
        require(_puzzle != 0);
        require(transferals[_puzzle].transferTo != 0);
        require(transferals[_puzzle].puzzle != 0);
        require(transferals[_puzzle].value != 0);
        require(transferals[_puzzle].expiry != 0);
        require(transferals[_puzzle].expiry < block.timestamp);
        
        uint v = transferals[_puzzle].value;
        transferals[_puzzle].value = 0;
        transferals[_puzzle].transferTo = 0; // transferals[_puzzle] marked as "empty"
        emit unloaded (_beneficiary, _puzzle, v);
        owner.transfer(v);
    }
    
    function releaseTransfer(string pw) public isRunning {
        bytes32 p = keccak256(msg.sender, pw);
        require(transferals[p].transferTo == msg.sender);
        require(transferals[p].puzzle == p);
        require(transferals[p].value > 0);
        require(transferals[p].expiry >= block.timestamp);
        
        uint v = transferals[p].value;
        transferals[p].value = 0;
        transferals[p].transferTo = 0;  // transferals[p] marked as "empty"
        emit released (msg.sender, p, v);
        msg.sender.transfer(v);
    }
}
