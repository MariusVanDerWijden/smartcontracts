pragma solidity 0.5.11;

library Uint64Lib {

	function getUint64(bytes32 data, uint8 index) public pure returns (uint64 out) {
		assembly {
			out := shr(data, mul(index, 64))
			out := and(out, 0xFFFFFFFFFFFFFFFF)
		}
	}
	
	function getAllUint64(bytes32 data) public pure returns (uint64[] memory out) {
	    assembly {
	        out := msize()
            mstore(add(out, 0x00), 4) // set size to 4 elements
            for {let i := 0} lt(i, 4) {i := add(i, 1)}
            {
               let temp := shr(data, mul(i, 64)) // tmp >> 64 * i
			   mstore(add(out, mul(i, 0x20)), and(temp, 0xFFFFFFFFFFFFFFFF)) // out[i] = uint64(tmp)
            }
            mstore(0x40, add(out, 0xA0)) // update msize to 5 * 32
       
	    }
	}
	
	function pack(uint64[] memory data) public pure returns (bytes32 out) {
	    assembly {
	        for {let i := 0} lt(i, 4) {i := add(i, 1)}
	        {
	            data := add(data, 0x20)
	            let temp := shl(mload(data), mul(i, 64))
	            out := xor(out, temp)
	        }
	    }
	}
}