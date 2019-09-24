/* 
 * This file is part of the EnergySmartContracts (https://github.com/MariusVanDerWijden/smartcontracts).
 * Copyright (c) 2019 Marius van der Wijden.
 * 
 * This program is free software: you can redistribute it and/or modify  
 * it under the terms of the GNU General Public License as published by  
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but 
 * WITHOUT ANY WARRANTY; without even the implied warranty of 
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License 
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

pragma solidity 0.5.11;
pragma experimental ABIEncoderV2;

contract EnergyDeliveryContract {
    
    enum enityTaxonomy {HUMAN, COMPANY, PARTNERSHIP}
    
    enum contractState {NIL, OFFER, CONSIDERATION, DELIVERED, TERMINATED}
    
    struct entity {
        enityTaxonomy typename;
        address recAddress;
        string id;
        attributes additionalAttributes;
    }
    
    struct attributes {
        uint256 age;
    }
    
    struct offer {
        uint256 amount;
        uint256 pricePerKwH;
        uint256 fullPrice;
    }
    
    struct legalContract {
        entity arbitrator;
        entity[2] parties; // party0 is deliverer, party1 is acceptor
        offer consideration;
        contractState state;
        uint40 deliveryDate; // deliveryDate only set if energy was delivered
        uint40 terminationDate; // terminationDate > deliveryDate
        uint40 closingDate; // not set if contract is open
    }
    
    legalContract lc;
    
    function propose(entity memory deliverer, entity memory other, entity memory arbitrator, offer memory consideration) public {
        require(lc.state == contractState.NIL);
        require(deliverer.recAddress == msg.sender);
        require(consideration.amount * consideration.pricePerKwH == consideration.fullPrice);
        lc.arbitrator = arbitrator;
        lc.parties[0] = deliverer;
        lc.parties[1] = other;
        lc.consideration = consideration;
        lc.state = contractState.OFFER;
    }
    
    function accept() public payable {
        require(msg.sender == lc.parties[1].recAddress);
        require(lc.state == contractState.OFFER);
        require(msg.value == lc.consideration.fullPrice);
        if (lc.parties[1].typename == enityTaxonomy.HUMAN) 
            require(lc.parties[1].additionalAttributes.age > 18);
        advanceState();
    }
    
    function delivered() inState(contractState.CONSIDERATION) public {
        require(msg.sender == lc.arbitrator.recAddress);
        lc.deliveryDate = uint40(now);
        lc.terminationDate = uint40(now + 10 days);
        advanceState();
    }
    
    function terminate() inState(contractState.DELIVERED) public {
        require(now > lc.terminationDate);
        // prevent reentrency
        advanceState(); 
        payout();
        lc.closingDate = uint40(1);
    }
    
    function advanceState() internal {
        lc.state = contractState(uint(lc.state) + 1);
    }
    
    function payout() inState(contractState.TERMINATED) internal {
        address payable addr  = address( uint160(lc.parties[0].recAddress));
        addr.transfer(lc.consideration.fullPrice);
    }
    
    modifier onlyParty() {
        require(lc.parties[0].recAddress == msg.sender || lc.parties[1].recAddress == msg.sender);
        _;
    }
    
    modifier inState(contractState state) {
        require(lc.state == state);
        _;
    }
}