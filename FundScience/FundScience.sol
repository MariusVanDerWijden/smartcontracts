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
        require(newPaper.percentageOfHundred <= 100);
        require(paperValid(newPaper));
        papers.push(newPaper);
    }

    function paperValid(paper newPaper)public view returns (bool valid){
        uint percentage = newPaper.percentageOfHundred;
        for(uint i = 0; i < papers.length; i++){
            percentage += papers[i].percentageOfHundred;
        }
        return percentage <= 100;
    }

    function () public payable {
        uint value = msg.value;
        if(value > negligible){
            for(uint i = 0; i < papers.length; i++){
                uint eth = (papers[i].percentageOfHundred * msg.value) / 100;
                value -= eth;
                require(value > 0);
                papers[i].paperAddress.send(eth);
            }
        }
        owner.send(value);
    }
}
