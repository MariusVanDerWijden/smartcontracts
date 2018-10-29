//------------------------------------------------------------------
//Solidity contract for encrypted storage of data, to be used with a fair exchange protocol
//Developed by Marius van der Wijden
//------------------------------------------------------------------

pragma solidity ^0.4.21;

contract EncryptedStorage{

	struct dataCell{
		address provider;
		bytes32 hash;
		bool initialized;
		byte encryptedData;
	}

	//Owner should not be affiliated to any users, 
	//since he can close the contract, 
	//even if other contracts depend on it
	address contractOwner;
	
	mapping (address => mapping (uint => dataCell)) dataStorage;

	event Storage_Opened();
	event Item_Stored(address owner, address provider, bytes32 hash);
    event Event_Selfdestruct();

	modifier onlyUser(address a){ 
		require(a == msg.sender); 
		_; 
	}

	constructor() public
	{
		emit Storage_Opened();
	}

	function storeData(address _owner, uint _dataCell, bytes32 _hash, byte _data) 
	    public
	{
		require(!dataStorage[_owner][_dataCell].initialized);
		dataStorage[_owner][_dataCell].hash = _hash;
		dataStorage[_owner][_dataCell].encryptedData = _data;
		dataStorage[_owner][_dataCell].provider = msg.sender;
		dataStorage[_owner][_dataCell].initialized = true;
	}

	function valid(address _owner, uint _dataCell, bytes32 _key) 
	    public view returns (bool)
	
	{
		bytes32 result;
		byte _data = dataStorage[_owner][_dataCell].encryptedData[i];
		
		for(uint i = 0; i < _data.length/32 + 1; i++)
		{
			bytes32 temp;
			uint offset = i * 32;
			for (uint q = 0; q < 32; q++) {
    			temp |= bytes32(_data[offset + q] & 0xFF) >> (q * 8);
  			}
			result ^= keccak256(abi.encodePacked(_key, i, temp));
		}
		return (keccak256(abi.encodePacked(result)) == dataStorage[_owner][_dataCell].hash);
	}

	function close() public onlyUser(contractOwner)
	{
		selfdestruct(contractOwner);
		emit Event_Selfdestruct();
	}
}