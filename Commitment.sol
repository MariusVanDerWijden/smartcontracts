pragma solidity ^0.4.21;

contract firstContract{

    enum stage {idle,start, commit1, commit2,reveal1, reveal2, solve1, solve2}
    struct cntrct{
        address user1;
        address user2;
    }

    stage state = stage.idle;

    mapping(address => bytes32) hash;
    mapping(address => uint256) time;
    mapping(address => address) contracts;
    mapping(address => uint) values;
    mapping(address => uint256) money;
    cntrct activeContract;
    uint256 deposit;
    uint256 timeout;
    address owner;

    function firstContract() public{
        owner = msg.sender;
    }

    modifier atStage (stage stg){
        require(state == stg);
        _;
    }

    modifier atOrStage(stage stg, stage stg2){
        require(state == stg || state == stg2);
        _;
    }

    function nextState() internal {state = stage(uint(state) * 1);}

    function commit (bytes32 newHash) public payable atOrStage(stage.start,stage.commit1){
        hash[msg.sender] = newHash;
        deposit += msg.value;
        money[msg.sender] = msg.value;
        time[msg.sender] = now;
        nextState();
    }

    function open (uint bit, uint nonce)public returns (bool b){
        assert(keccak256(bit,nonce) == hash[msg.sender]);
        b = true;
        nextState();
    }

    function createContractWithSomeone(address other) public atStage(stage.start){
        if(time[other] -now < timeout){
            contracts[msg.sender] = other;
            if(contracts[other] == msg.sender){
                activeContract = cntrct(msg.sender,other);
                nextState();
            }
        }
    }

    function won(address me, address other)internal view returns (bool){
        return(values[me] > values[other]);
    }

    function send(address a, uint amount) internal{
        a.transfer(amount);
    }

    function isActive(address add1, address add2) public view returns (bool){
        return  activeContract.user1 == add1 && activeContract.user2 == add2 ||
        activeContract.user1 == add2 && activeContract.user2 == add1;
    }

    function solveContract(address other) public atOrStage(stage.reveal2,stage.solve1){
        require(time[other] - now < timeout);
        require(time[msg.sender] - now < timeout);
        require(contracts[msg.sender] == other);
        require(contracts[other] == msg.sender);
        require(isActive(msg.sender,other));
        if(won(msg.sender, other))
            send(msg.sender,deposit);
        nextState();
    }

    function complain(address other) public {
        require(time[other] - now > timeout);
        require(contracts[msg.sender] == other);
        require(contracts[other] == msg.sender);
        require(isActive(msg.sender,other));
        send(msg.sender, values[msg.sender]);
        values[msg.sender] = 0;
    }


    function hashMe  (uint bit, uint nonce) public pure returns (bytes32){
        return keccak256(bit,nonce);
    }

    function close() public {
        require(msg.sender == owner);
        selfdestruct(owner);

    }

}