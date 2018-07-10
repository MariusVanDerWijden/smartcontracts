pragma solidity ^0.4.21;
pragma experimental ABIEncoderV2;

import "./IGame.sol";

contract StateChannel{

	enum State {PROPOSED,ACCEPTED,DISPUTE,GAME_STARTED,GAME_STOPPED,FINISHED,CLOSED}
	//PROPOSED -> ACCEPTED //if bob accepts the ledger channel
	//PROPOSED -> CLOSED  //if bob declines the ledger channel (after timeout)
	//ACCEPTED -> DISPUTE //if a/b wants to close the virtual channel
	//DISPUTE  -> FINISHED //if b/a accepts the closing of the virtual channel
	//DISPUTE  -> GAME_STARTED //if b/a declines the closing of the game -> game has to be started
	//GAME_STARTED -> GAME_STOPPED //if a/b wants to stop the game
	//GAME_STOPPED -> FINISHED //if b/a accepts closing the game (or timeout is up)
	//FINISHED -> CLOSED //funds are distributed between parties
	address alice;
	address bob;
	IGame game;
	uint256 aliceValue;
	uint256 bobValue;
	uint256 endTimeout;
	address stopUser;
	uint constant maxTimeout = 10 seconds;
	State state;

	uint256 tmpAlice;
	uint256 tmpBob;

	event Event_Channel_Proposed(uint256 funds, address game, address bob);
    event Event_Channel_Accepted(uint256 aliceValue,uint256 bobValue);
    event Event_Stop_Proposed(uint256 aliceValue,uint256 bobValue);
    event Event_Stop_Accepted(uint256 aliceValue,uint256 bobValue);
    event Event_Stop_Disputed(uint256 aliceValue,uint256 bobValue);
    event Event_Game_Started(uint256 aliceValue,uint256 bobValue, address game);
	event Event_Game_Stop_Proposed();
	event Event_Game_Stop_Accepted(uint256 aliceValue,uint256 bobValue);
    event Event_Payout();
    event Event_Selfdestruct();

	modifier onlyUser(address a){ require(a == msg.sender); _; }

    modifier onlyMember{ require(alice == msg.sender || bob == msg.sender); _; }

    modifier inState(State s){ require(state == s); _;}

    modifier inOrState(State s, State q){ require(state == s || state == q); _;}

    function other(address _address)private view returns (address) 
    {
		if(_address == alice)
			return bob;
		if(_address == bob)
			return alice;
		return 0;
	}

	constructor(address _bob, address _game) public payable
	{
		alice = msg.sender;
		bob = _bob;
		state = State.PROPOSED;
		aliceValue = msg.value;
		endTimeout = now + maxTimeout;
		game = IGame(_game);
		emit Event_Channel_Proposed(msg.value,_game,_bob);
	}

	function accept() onlyUser(bob) inState(State.PROPOSED) public payable
	{
		require(msg.value >= aliceValue);
		state = State.ACCEPTED;
		bobValue = msg.value;
		endTimeout = now + maxTimeout;
		emit Event_Channel_Accepted(aliceValue,bobValue);
	}

	function stopChannel(uint256 _aliceValue, uint256 _bobValue) public onlyMember inState(State.ACCEPTED)
	{
		require(endTimeout > now);
		require(_aliceValue + _bobValue <= aliceValue + bobValue);
		tmpAlice = _aliceValue;
		tmpBob = _bobValue;
		stopUser = msg.sender;
		state = State.DISPUTE;
		emit Event_Stop_Proposed(_aliceValue,_bobValue);
	}

	function acceptStop(uint256 _aliceValue, uint256 _bobValue) 
		public onlyUser(other(stopUser)) inState(State.DISPUTE)
	{
		require(endTimeout > now);
		require(_aliceValue + _bobValue <= aliceValue + bobValue);
		require(tmpAlice == _aliceValue && tmpBob == _bobValue);
		state = State.FINISHED;
		aliceValue = tmpAlice;
		bobValue = tmpBob;
		emit Event_Stop_Accepted(_aliceValue, _bobValue);
	}

	function disputeStop_StartGame() public onlyUser(other(stopUser)) inState(State.DISPUTE)
	{
		require(endTimeout > now);
		require(msg.sender == other(stopUser));
		game.init(address(this), alice ,aliceValue, bobValue, bob, maxTimeout);
		stopUser = address(0);
		state = State.GAME_STARTED;
		endTimeout = now + maxTimeout;
		emit Event_Game_Started(aliceValue, bobValue, game);
	}

	function proposeStopGame() public onlyMember inState(State.GAME_STARTED)
	{
		require(endTimeout < now);
		stopUser = msg.sender;
		state = State.GAME_STOPPED;
		emit Event_Game_Stop_Proposed();
	}

	function acceptStopGame() public onlyMember inState(State.GAME_STOPPED)
	{
		require((endTimeout < now && msg.sender == other(stopUser)) || endTimeout > now);
		address a; address b; uint256 av; uint256 bv;
		(a, av, b, bv) = game.close();
		require(av + bv <= aliceValue + bobValue); //prevent money printing
		state = State.FINISHED;
		aliceValue = av;
		bobValue = bv;
		endTimeout = maxTimeout;
		emit Event_Game_Stop_Accepted(aliceValue, bobValue);
	}	

	function payout() public inState(State.FINISHED) onlyMember
	{
        require(alice.send(aliceValue));
        require(bob.send(bobValue));
		state = State.CLOSED;
		emit Event_Payout();
	}

	/* 
		Close the channel if timeout is over and bob hasn't replied or the money has been payed out
	*/
	function close() public inOrState(State.CLOSED, State.PROPOSED) onlyUser(alice)
	{
		require(endTimeout < now);
		state = State.CLOSED;
		selfdestruct(alice);
		emit Event_Selfdestruct();
	}

}