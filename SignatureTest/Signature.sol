pragma solidity ^0.4.21;
//pragma experimental ABIEncoderV2;


contract Signature{

	event Event_Tick();
	event Event_Data(uint a, bytes32 data);
	event Event_Tock();
	//event Event_Opened(address a, bytes32 hash, uint8 v, bytes32 r, bytes32 s);

	constructor() public payable {
		emit Event_Tick();
	}

	function init(bytes32 data, address data2) 
	{
		bytes32 _hash = keccak256(abi.encode(1234));
		bytes32 _hash2 = keccak256(abi.encodePacked("1234",data2));
		bytes32 _hash3 = keccak256(abi.encodePacked(1234,data2));
		bytes32 _hash4 = keccak256(abi.encode('1234',data2));
		bytes32 _hash5 = keccak256(abi.encode(data2));
		bytes32 _hash6 = keccak256(data2);
		bytes32 _hash7 = keccak256(abi.encodePacked(data2));
		uint t = 1234;
		bytes32 _hash8 = keccak256(abi.encodePacked(t,data2));

		//bytes32 _hash6 = sha256(abi.encode())
		//bytes b = data + data2;
		//bytes32 _hash_2 = keccak256(b);
		emit Event_Data(0,_hash);
		emit Event_Data(1,_hash2);
		emit Event_Data(2,_hash3);
		emit Event_Data(4,_hash4);	
		emit Event_Data(5,_hash5);
		emit Event_Data(6,_hash6);
		emit Event_Data(7,_hash7);
		emit Event_Data(8,_hash8);
		//emit Event_Data(3,_hash_2);
		emit Event_Tock();
	}

	function verify(bytes32 hash, uint8 v, bytes32 r, bytes32 s, address signer)public returns(bool) {
    	bytes memory prefix = "\x19Ethereum Signed Message:\n32";
    	bytes32 prefixedHash = sha3(abi.encodePacked(prefix, hash));
    	address rec = ecrecover(prefixedHash, v, r, s);

    	emit Event_Data(1,hash);
    	emit Event_Data(2,s);
    	emit Event_Data(3,r);
    	emit Event_Data(v,0);
    	emit Event_Data(11,prefixedHash);
    	emit Event_Data(12,bytes32(rec));
    	emit Event_Data(13,bytes32(msg.sender));
    	if(rec == signer)
    		emit Event_Data(122434345,0);
    	return true;
    	//return rec == signer;
	}

}