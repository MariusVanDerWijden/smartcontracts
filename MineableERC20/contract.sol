// SPDX-License-Identifier: GPLv3
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.8/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    
    bytes32 target;

    constructor () ERC20("MineableToken", "MTK") {
        _setupDecimals(2);
        target = ~bytes32(0);
    }
    
    function mine(uint256 nonce) public {
        bytes memory enc = abi.encode(msg.sender, nonce);
        bytes32 hash = keccak256(enc);
        if(hash < target) {
            target = hash;
            _mint(msg.sender, 1 * (10 ** uint256(decimals())));
        }
    }
}
