pragma solidity ^0.4.21;
pragma experimental ABIEncoderV2;

import "./IGame.sol";

contract RockPaperScissors is IGame{

    address alice;
    address bob;
    address game;
    address _contract;
    uint256 maxTimeout;
    uint256 endTimeout;

    event Event_Initialized(uint256 aliceValue, uint256 bobValue);
    event Event_State_Applied(uint256 aliceValue, uint256 bobValue, uint256 time, bytes32 hash);
    event Event_State_Finalized(uint256 counter);
    event Event_Commit(address sender, bytes32 hash);
    event Event_Reveal(address sender, uint8 value);
    event Event_Game_Closed(uint256 aliceValue, uint256 bobValue);


    enum stage {idle,start, commit1, commit2,reveal1, reveal2, solve1, solve2}
    enum rps {DEFAULT,ROCK,PAPER,SCISSORS}
    struct internalState{
        bytes32 stateHash;
        bytes32 hash_a;
        bytes32 hash_b;
        rps value_a;
        rps value_b;
        stage state;
        uint256 aliceValue;
        uint256 bobValue;
        uint256 counter;
        address lock_address;
    }
    internalState channelState;
    mapping (address => internalState) initChannelState;

    modifier onlyUser(address a){ require(a == msg.sender); _; }

    modifier onlyMember{ require(bob == msg.sender || alice == msg.sender); _; }

    modifier atStage (stage stg){ require(channelState.state == stg); _; }
    modifier atOrStage (stage stg, stage stg2){ require(channelState.state == stg || channelState.state == stg2); _; }

    function nextState() internal 
    {
        channelState.state = stage(uint(channelState.state) * 1);
        channelState.counter = channelState.counter + 1;
    }

    function lockAddress() internal{
        if(channelState.lock_address != address(0)){
            require(channelState.lock_address != msg.sender);
            channelState.lock_address = address(0);
        }else{
            channelState.lock_address = msg.sender;
        }
    }

    function other(address _address)private view returns (address) 
    {
        if(_address == alice)
            return bob;
        if(_address == bob)
            return alice;
        return 0;
    }

    constructor() public payable {}

    function init(address __contract, address _alice, uint256 _aliceValue, uint256 _bobValue, address _bob, uint256 timeout) 
    external returns(bool){
        alice = _alice;
        bob = _bob;
        channelState.aliceValue = _aliceValue;
        channelState.bobValue = _bobValue;
        maxTimeout = timeout;
        endTimeout = now + timeout; //2 Million
        _contract = __contract;
        channelState.state = stage.start;
        channelState.value_a = rps.DEFAULT;
        channelState.value_b = rps.DEFAULT;
        channelState.counter = 1;
        channelState.lock_address = address(0);
        emit Event_Initialized(_aliceValue, _bobValue);
        return true;
    }

    //member can commit twice
    function commit (bytes32 newHash) public onlyMember atOrStage(stage.start,stage.commit1){
        require(endTimeout > now);
        lockAddress();
        if(msg.sender == alice)
            channelState.hash_a = newHash;
        else
            channelState.hash_b = newHash;

        emit Event_Commit(msg.sender, newHash);
        nextState();
    }

    function open(rps bit, uint nonce)public onlyMember atOrStage(stage.commit2, stage.reveal1){
        require(endTimeout > now);
        lockAddress();
        bool b = (msg.sender == alice && keccak256(abi.encodePacked(bit,nonce)) == channelState.hash_a) ||
                (msg.sender == bob && keccak256(abi.encodePacked(bit,nonce)) == channelState.hash_b);
        //require(b); abi.encodePacked currently breaks the opening process
        if(msg.sender == alice)
             channelState.value_a = bit;
        else
            channelState.value_b = bit;
        emit Event_Reveal(msg.sender, uint8(bit));
        nextState();
    }

    function applyStateInit(bytes32 hash_a, bytes32 hash_b, uint8 value_a, 
        uint8 value_b, uint8 state, address lock_address, uint256 _aliceValue, 
        uint256 _bobValue, uint256 _counter) public onlyMember
    {
        
        require(endTimeout > now);
        
        bytes32 hash = keccak256(abi.encodePacked(
            hash_a, hash_b, uint(value_a), uint(value_b), uint(state),
            _aliceValue, _bobValue, _counter, lock_address));
  
        
        initChannelState[msg.sender].stateHash = hash;
        initChannelState[msg.sender].hash_a = hash_a;
        initChannelState[msg.sender].hash_b = hash_b;
        initChannelState[msg.sender].value_a = rps(value_a);
        initChannelState[msg.sender].value_b = rps(value_b);
        initChannelState[msg.sender].state = stage(state);
        initChannelState[msg.sender].aliceValue = _aliceValue;
        initChannelState[msg.sender].bobValue = _bobValue;
        initChannelState[msg.sender].lock_address = lock_address;
        initChannelState[msg.sender].counter = _counter;

        endTimeout = now + maxTimeout;
        emit Event_State_Applied(_aliceValue, _bobValue, _counter, hash);
    }

    function applyStateFinalize(bytes32 hash, bytes32 r, uint8 v, bytes32 s) public onlyMember
    {
        require(initChannelState[msg.sender].stateHash == hash);
        address _other = other(msg.sender);
        require(verify(hash, v, r, s, _other));
        require(initChannelState[msg.sender].counter > channelState.counter);
        channelState = initChannelState[msg.sender];
        emit Event_State_Finalized(initChannelState[msg.sender].counter);
    }

    function verify(bytes32 hash, uint8 v, bytes32 r, bytes32 s, address signer)private pure returns(bool) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, hash));
        ecrecover(hash, v, r, s) == signer;
        return true;
    }

    function endGame() internal
    {   
        int8 winner = won();
        if(winner == 0)
        {
            channelState.state = stage.start;
            return;
        }
        if(winner == 1){
            channelState.aliceValue = channelState.aliceValue + channelState.bobValue;
            channelState.bobValue = 0;
        }
        if(winner == -1){
            channelState.bobValue = channelState.bobValue + channelState.aliceValue;
            channelState.aliceValue = 0;
        }
        channelState.state = stage.idle;
    }

    function won()internal view returns (int8)
    {
        if(channelState.value_a == channelState.value_b) return 0;
        if(channelState.value_a == rps.ROCK && channelState.value_b == rps.SCISSORS) return 1;
        if(channelState.value_a == rps.PAPER && channelState.value_b == rps.ROCK) return 1;
        if(channelState.value_a == rps.SCISSORS && channelState.value_b == rps.PAPER) return 1;
        if(channelState.value_a == rps.DEFAULT) return -1; //me didn't send a result
        if(channelState.value_b == rps.DEFAULT) return 1; //other didn't send a result
        return -1;
    }

    function hashMe (uint bit, uint nonce) public pure returns (bytes32){
        return keccak256(abi.encodePacked(bit,nonce));
    }

    function close() external onlyUser(_contract) returns (address _alice, uint256 _aliceValue, address _bob, uint256 _bobValue) {
        require(endTimeout < now);
        if(channelState.state != stage.idle)
            endGame();
        if(channelState.state != stage.idle && channelState.state != stage.start)
            return;
        _alice = alice;
        _bob = bob;
        _aliceValue = channelState.aliceValue;
        _bobValue = channelState.bobValue;
        emit Event_Game_Closed(_aliceValue,_bobValue);
    }

}