pragma solidity ^0.4.21;

interface ISecureStorage {
    function valid(address _owner, uint _dataCell, bytes32 _key) external view returns (bool);
}
