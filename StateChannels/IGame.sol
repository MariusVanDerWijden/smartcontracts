pragma solidity ^0.4.0;

interface IGame {
    function init
    (address __contract, address _alice, uint256 _aliceValue, uint256 _bobValue, address _bob, uint256 timeout) 
    	external returns(bool);
    function close() external returns (address _alice, uint256 _aliceValue, address _bob, uint256 _bobValue);
}
