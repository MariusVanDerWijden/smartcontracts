//------------------------------------------------------------------
//Solidity contract for the fair exchange of digital encryption keys
//Developed by Marius van der Wijden
//------------------------------------------------------------------

pragma solidity ^0.4.21;

contract ExchangeContract{

	enum State {PROPOSED,ACCEPTED,DISPUTE,CLOSED}

	struct ExchangeState {
		address alice;
		address bob;
		uint256 aliceValue;
		uint256 bobValue;
		byte[] firstHalfKeys; //the first half of the key, encrypted with bob's pk
		byte32[] firstHalfHashes;
		byte32[] secondHalfKeys;
		address[] valueAddresses;
		State state = State.CLOSED;
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

	constructor()
	{
		emit Exchange_Opened();
		openExchanges = 0;
	}

	function proposeExchange (
		uint256 exchangeID, 
		address _bob, 
		address[] _valueAddresses, 
		byte[] _firstHalfKeys,
		byte32[] _firstHalfHashes
	)
		inState(exchangeID, State.CLOSED) public payable
	{
		exchanges[exchangeID].alice = msg.sender;
		exchanges[exchangeID].aliceValue = msg.value;
		exchanges[exchangeID].bob = _bob;
		exchanges[exchangeID].valueAddresses = _valueAddresses;
		exchanges[exchangeID].firstHalfKeys = _firstHalfKeys;
		exchanges[exchangeID].firstHalfHashes = _firstHalfHashes;
		exchanges[exchangeID].state = State.PROPOSED;
		exchanges[exchangeID].timeout = now + maxTimeout;
		emit Exchange_Proposed(exchangeID, msg.sender, _bob);
		openExchanges = openExchanges + 1;
	}

	function acceptExchange (
		uint256 exchangeID, 
		byte32[] _secondHalfKeys
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
		byte32 firstKeyHalf
	)
		onlyUser(exchanges[exchangeID].alice)
		inState(exchangeID, State.ACCEPTED)
	{
		require(now > exchanges[exchangeID].timeout);
		require(keccak256(firstKeyHalf) = exchanges[exchangeID].firstHalfHashes[keyID]);
		byte32 key = firstKeyHalf ^ secondHalfKeys[keyID];
		bool valid = exchanges[exchangeID].valueAddresses[keyID].valid(key);
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
		require(openExchanges = 0);
		selfdestruct(owner);
		emit Event_Selfdestruct();
	}
}