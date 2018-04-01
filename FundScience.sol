pragma solidity ^0.4.0;
pragma experimental ABIEncoderV2;

contract FundScience {

    struct paper{
        address paperAddress;
        string paperName;
        uint percentageOfHundred;
    }

    address owner;
    string nameOfPaper;
    mapping (address => uint) balance;
    uint deposit = 0;
    uint negligible = 1000;
    paper[] papers;

    function FundScience (string name) public{
        owner = msg.sender;
        nameOfPaper = name;
    }

    function addPaper(paper newPaper) public{
        require(msg.sender == owner);
        papers.push(newPaper);
    }

    function sendEther() public payable {
        uint value = msg.value;
        if(value > negligible){
            for(uint i = 0; i < papers.length; i++){
                require(papers[i].percentageOfHundred <= 100);
                uint eth = (papers[i].percentageOfHundred * msg.value) / 100;
                value -= eth;
                require(value > 0);
                FundScience tmp = FundScience(papers[i].paperAddress);
                tmp.sendEther.value(eth)();
            }
        }
        owner.transfer(value);
    }
}
