pragma solidity 0.5.11;

library Uint8Lib {

	function getUint8(bytes32 data, uint8 index) public pure returns (uint64 out) {
		assembly {
			out := shr(data, mul(index, 64))
			out := and(out, 0xFF)
		}
	}
	
	function unpack(uint256 data) public pure returns (uint8[32] memory out) {
	    for (uint i = 0; i < 32; i++) {
	        out[i] = uint8(data >> i * 8);
	    }
	}
	
	function pack(uint8[32] memory data) public pure returns (uint256 out) {
	    for (uint i = 0; i < 32; i++) {
	        out |= uint256(data[i]) << i * 8;
	    }
	}
}

contract TestLib {
    
    using Uint8Lib for uint8[32];
    using Uint8Lib for uint256;
    
    function test() public pure {
        uint8[32] memory a = [0,1, 2,3,4,5,6,7,8,9,10,11,12,13,115,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32];
        uint256 packed = a.pack();
        uint8[32] memory b = packed.unpack();
        for (uint i = 0; i < 32; i++) {
            require(a[i] == b[i]);
        }
    }
}
