pragma solidity ^0.6.0;

contract IncentiviceMiner {
    
    address owner;
    address censor;
    uint256 rewardPerBlock;
    uint256 timeout;
    mapping(address => uint256) rewards;
    uint256 lastBlockTimestamp;
    bool failed;
    
    modifier notFailed() {
        require(!failed, "Incentive failed");
        _;
    }
    
    modifier oncePerBlock() {
        require(lastBlockTimestamp != now, "Reward already claimed");
        lastBlockTimestamp = now;
        _;
    }
    
    constructor(uint256 _;rewardPerBlock, uint256 timeline, address _censor) function payable {
        owner = msg.sender;
        require(rewardPerBlock * timeline == msg.value, "Send more eth");
        timeout = now + timeline;
        rewardPerBlock = _rewardPerBlock;
        censor = _censor;
        failed = false;
    }
    
    function claimReward() external notFailed oncePerBlock {
        rewards[block.coinbase] += rewardPerBlock;
    }
    
    function payout(address payable miner) notFailed external {
        require(now > timeout, "can only payout after timeout");
        reward = rewards[miner];
        rewards[miner] = 0;
        miner.transfer(reward);
    }
    
    function dispute(bytes merklePath, uint256 blockNum) notFailed external {
        merkleRoot = block.blockhash(blockNum);
        txSender, valid = readMerklePath(merkleRoot, merklePath);
        require(valid, "invalid merklepath");
        require(tx == censor, "invalid tx sender");
        failed = true;
    } 
    
    function selfdes() external {
        require(failed, "Can only selfdestruct if incentive failed");
        require(now > timeout, "only selfdestruct after timeout");
        selfdestruct(owner);
    }
    
    function readMerklePath(bytes merklepath, bytes32 merkleroot) pure returns (address, bool) {
        
    }
    
}