//------------------------------------------------------------------
//Solidity contract for the fair exchange of digital encryption keys
//Developed by Marius van der Wijden
//------------------------------------------------------------------

pragma solidity ^0.4.21;

import "./ISecureStorage.sol";

contract ExchangeContract{

	enum State {PROPOSED,ACCEPTED,CLOSED}

	struct ExchangeState {
		address alice;
		address bob;
		uint256 aliceValue;
		uint256 bobValue;
		byte[] firstHalfKeys; //the first half of the key, encrypted with bob's pk
		bytes32[] firstHalfHashes; //the hash of the first half
		bytes32[] secondHalfKeys; //the second half of the key
		address storageAddress; //the addresses where the data can be found
		uint[] dataCells; //the dataCells of the data
		State state;
		uint256 timeout;
    }
	uint constant maxTimeout = 10 seconds;

	uint openExchanges;
	address owner;
	
	mapping (uint => ExchangeState) public exchanges;

	event Exchange_Opened();
	event Exchange_Proposed(uint exchange, address alice, address bob);
    event Exchange_Accepted(uint exchange, address alice, address bob);
    event Exchange_Closed(uint exchange);
    event Exchange_Timeout(uint exchange);
    event Exchange_Disputed(uint exchange, bool successful);
    event Event_Selfdestruct();

	modifier onlyUser(address a){ 
		require(a == msg.sender); 
		_; 
	}

    modifier inState(uint exchangeID, State s){ 
    	require(exchanges[exchangeID].state == s); 
    	_;
    }

	constructor() public
	{
		emit Exchange_Opened();
		openExchanges = 0;
	}

	function proposeExchange (
		uint256 exchangeID, 
		address _bob, 
		address _storageAddress,
		uint[] _dataCells,
		byte[] _firstHalfKeys,
		bytes32[] _firstHalfHashes
	)
		inState(exchangeID, State.CLOSED) public payable
	{
		exchanges[exchangeID].alice = msg.sender;
		exchanges[exchangeID].aliceValue = msg.value;
		exchanges[exchangeID].bob = _bob;
		exchanges[exchangeID].storageAddress = _storageAddress;
		exchanges[exchangeID].dataCells = _dataCells;
		exchanges[exchangeID].firstHalfKeys = _firstHalfKeys;
		exchanges[exchangeID].firstHalfHashes = _firstHalfHashes;
		exchanges[exchangeID].state = State.PROPOSED;
		exchanges[exchangeID].timeout = now + maxTimeout;
		emit Exchange_Proposed(exchangeID, msg.sender, _bob);
		openExchanges = openExchanges + 1;
	}

	function acceptExchange (
		uint256 exchangeID, 
		bytes32[] _secondHalfKeys
	) 
		onlyUser(exchanges[exchangeID].bob) 
		inState(exchangeID, State.PROPOSED) public payable
	{
		require(msg.value >= exchanges[exchangeID].aliceValue);
		require(now < exchanges[exchangeID].timeout);
		exchanges[exchangeID].bobValue = msg.value;
		exchanges[exchangeID].secondHalfKeys = _secondHalfKeys;
		exchanges[exchangeID].state = State.ACCEPTED;
		exchanges[exchangeID].timeout = now + maxTimeout;
		emit Exchange_Accepted(exchangeID, exchanges[exchangeID].alice, msg.sender);
	}

	function finishExchange (
		uint256 exchangeID
	)   
	    public
		inState(exchangeID, State.ACCEPTED)
	{
		require(now > exchanges[exchangeID].timeout);
		exchanges[exchangeID].state = State.CLOSED;
		uint256 value = exchanges[exchangeID].bobValue + exchanges[exchangeID].aliceValue;
		require(exchanges[exchangeID].bob.send(value));
		emit Exchange_Closed(exchangeID);
		openExchanges = openExchanges - 1;
	}

	function timeoutExchange (
		uint256 exchangeID
	)
	    public
		onlyUser(exchanges[exchangeID].alice) 
		inState(exchangeID, State.PROPOSED)
	{
		require(now > exchanges[exchangeID].timeout);
		exchanges[exchangeID].state = State.CLOSED;
		require(exchanges[exchangeID].alice.send(exchanges[exchangeID].aliceValue));
		emit Exchange_Closed(exchangeID);
		openExchanges = openExchanges - 1;
	}

	function disputeExchange(
		uint256 exchangeID,
		uint256 keyID,
		bytes32 firstKeyHalf
	)
	    public
		onlyUser(exchanges[exchangeID].alice)
		inState(exchangeID, State.ACCEPTED)
	{
		require(now > exchanges[exchangeID].timeout);
		require(keccak256(abi.encodePacked(firstKeyHalf)) 
		    == exchanges[exchangeID].firstHalfHashes[keyID]);
		bytes32 key = firstKeyHalf ^ exchanges[exchangeID].secondHalfKeys[keyID];
		ISecureStorage store = ISecureStorage(exchanges[exchangeID].storageAddress);
		bool valid = store.valid(
			exchanges[exchangeID].bob, 
			exchanges[exchangeID].dataCells[keyID],
			key);
		exchanges[exchangeID].state = State.CLOSED;
		uint256 value = exchanges[exchangeID].bobValue + exchanges[exchangeID].aliceValue;
		if(valid) //key was a valid key for the value -> alice cheated
		{
			require(exchanges[exchangeID].bob.send(value));
		}
		else //key was not a valid key -> bob cheated
		{
			require(exchanges[exchangeID].alice.send(value));
		}
		openExchanges = openExchanges - 1;
		emit Exchange_Closed(exchangeID);
		emit Exchange_Disputed(exchangeID, !valid);
	}

	function close() public onlyUser(owner)
	{
		require(openExchanges == 0);
		selfdestruct(owner);
		emit Event_Selfdestruct();
	}
}