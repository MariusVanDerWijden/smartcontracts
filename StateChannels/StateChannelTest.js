const utils = require('ethereumjs-util');
const abi = require('ethereumjs-abi');

var aliceMoney;
var bobMoney;

let gasUsedTotal = 0;
let functionCalls = [];

function called(label, gasUsed){
    gasUsedTotal += gasUsed;
    var priceWEI = gasUsed * gasPrice;
    var priceETH = web3.utils.fromWei(String(priceWEI), "ether");
    var priceUSD = priceETH * 400;
    functionCalls.push(label + "\t: " + gasUsed + "\t " + priceETH + "\t" + priceUSD);
}

function overview(){
    var priceWEI = gasUsedTotal * gasPrice;
    var priceETH = web3.utils.fromWei(String(priceWEI), "ether");
    var priceUSD = priceETH * 400;
    console.log("---------");
    console.log("Function name \t: gas used \t price in ETH \t price in USD")
    console.log("Total gas used\t: " + gasUsedTotal + "\t " + priceETH + "\t" + priceUSD);
    for(let i = 0; i < functionCalls.length; ++i)
        console.log(functionCalls[i]); "\t"
    console.log("---------");
}


//Generates a signature for a specific user
async function genSig(args, address) {
    let hash = await web3.utils.sha3(args);
    let sign = await web3.eth.sign(hash,address);
    return sign;
}

async function hash(contract, bit, nonce, address) {
    resp = await contract.methods.hashMe(bit,nonce);
    var snd = await resp.send({
        from: address,
        gas: '2000000',
        gasPrice: '1'
    }).catch((error) => {console.log(error)});
    console.log("HashMe called successful: "+snd);
    return snd;
}

//Compiles the smart contract
function getContract(contractName) {
    exec('solc --bin --abi --optimize --overwrite -o build/ '+contractName+'.sol');

    var code = "0x" + fs.readFileSync("build/" + contractName + ".bin");
    var abi = fs.readFileSync("build/" + contractName + ".abi");
    return {
        abi: abi,
        code: code
    };
}

//Deploys the contract on the blockchain
async function deployState(gameaddress, game) {
    console.log('Starting deployment');
    var state = getContract("StateChannel");
    var contract = new web3.eth.Contract(
        JSON.parse(state.abi), 
        {from: aliceAddr, data: state.code, gas: '200000000'});
    await contract.deploy({
         data: state.code,
         arguments: [bobAddr, gameaddress],
         value: web3.utils.toWei("10", "ether")
     }).send(
        {   from: aliceAddr,
            gas: '4000000',
            gasPrice: '3',
            value: web3.utils.toWei("10", "ether")}
        , function (e, contract){
           if(e){
            console.log(e);
           }
           if (typeof contract.address !== 'undefined') {
               console.log('Contract mined! address: ' + contract.address + 
                ' transactionHash: ' + contract.transactionHash);
           }
     }).then(async function(newContractInstance){
        console.log('StateChannel deployed at: ' + newContractInstance.options.address);
        console.log('asdf:' + game.options.address);    
        await runTests(newContractInstance, game);
    }).catch((error) => {console.log(error)});
}

async function deployGame(){
    console.log('Starting deployment of game');
    var state = getContract("RockPaperScissors");
    var contract = new web3.eth.Contract(JSON.parse(state.abi), 
        {from: aliceAddr, data: state.code, gas: '200000000'});
    await contract.deploy({
         data: state.code,
         value: web3.utils.toWei("10", "ether")
     }).send(
        {   from: aliceAddr,
            gas: '4000000',
            gasPrice: '3',
            value: web3.utils.toWei("10", "ether")}
        , function (e, contract){
           if(e){
            console.log(e);
           }
           if (typeof contract.address !== 'undefined') {
               console.log('Contract mined! address: ' + contract.address + 
                ' transactionHash: ' + contract.transactionHash);
           }
     }).then(async function(newContractInstance){
        console.log('Game deployed at: ' + newContractInstance.options.address);
        await deployState(newContractInstance.options.address, newContractInstance);
    }).catch((error) => {console.log(error)});
}

//Helper function to add a timeout
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

//Runs the tests, acts as one run through the protocol
function runTests(state, game) {
    var events = game.events.allEvents({fromBlock: 0, toBlock: 'latest'},
        (async function(error, event) {
        if (!error) {
            console.log(event.event);
            if(event.event == "Event_Initialized"){
                console.log("Game was initialized with alice: "+
                    event.returnValues.aliceValue+" wei, bob: "+event.returnValues.bobValue);
                //Alice provides the last state of the state channel
                var hash_a = hash(game,1,12345,aliceAddr);
                var hash_b = hash(game,3,123123123,bobAddr);
                var value_a = 1; //rock = 1
                var value_b = 0; //undefined = 0
                var state = 4; //reveal = 4
                var lock_address = aliceAddr; //alice has provided the last reveal
                var _aliceValue = event.returnValues.aliceValue; //amount of money hasn't changed
                var _bobValue = event.returnValues.bobValue; //amount of money hasn't changed
                var _counter = 7; //can be arbitrary (alway increasing)
                //Bob has signed this state
                var sig_b = await genSig(
                    [hash_a, hash_b, value_a, value_b, state, 
                    lock_address, _aliceValue, _bobValue, _counter], bobAddr); //currently throws invalid type
                //Alice signs this state
                var sig_a = await genSig(
                    [hash_a, hash_b, value_a, value_b, state, 
                    lock_address, _aliceValue, _bobValue, _counter], aliceAddr);
                console.log("tock");
                resp = await game.methods.applyState(hash_a, hash_b, value_a, value_b,
                    state, lock_address, _aliceValue, _bobValue, _counter, sig_a, sig_b);

                console.log("tick");
                //Alice sends the last agreed upon state to the contract
                var snd = await resp.send({
                    from: aliceAddr,
                    gas: '2000000',
                    gasPrice: '1'
                }).catch((error) => {console.log(error)});
                console.log("Alice updates the contract on the blockchain");
                called("applyState", snd.gasUsed);

            }else if(event.event == "Event_State_Applied"){
                console.log("State applied with alice: "+
                    event.returnValues.aliceValue+" wei, bob: "+event.returnValues.bobValue + 
                    " channel time" + event.returnValues.time);
                //Bob has to open his commitment on the blockchain

                resp = await game.methods.open(3,123123123);

                //Alice sends the last agreed upon state to the contract
                var snd = await resp.send({
                    from: bobAddr,
                    gas: '2000000',
                    gasPrice: '1'
                }).catch((error) => {console.log(error)});
                console.log("Alice send the last state to the contract");
                called("open", snd.gasUsed);

            }else if(event.event == "Event_Reveal"){
                console.log("Commitment revealed: " + event.returnValues.value);
                //Alice proposes to stop the game
                resp = await state.methods.proposeStopGame();

                //Alice sends the last agreed upon state to the contract
                var snd = await resp.send({
                    from: aliceAddr,
                    gas: '2000000',
                    gasPrice: '1'
                }).catch((error) => {console.log(error)});
                console.log("Alice send the last state to the contract");
                called("proposeStopGame", snd.gasUsed);

            }else if(event.event == "Event_Game_Closed"){ 
                console.log("Game closed with alice: "+
                    event.returnValues.aliceValue+" wei, bob: "+event.returnValues.bobValue);

            }else{
                console.log("Unknown Event: "+event.event);
            }


        } else {
            console.log(error);
            console.log("Exiting");
            process.exit();
        }
    }));

    // setup State Channel watcher with async callbacks
    var events = state.events.allEvents({fromBlock: 0, toBlock: 'latest'},
        (async function(error, event) {
        if (!error) {
            console.log(event.event);
            //Event_Channel_Opened is thrown whenever the constructor is called
            if(event.event == "Event_Channel_Proposed") {
                //Alice opened the channel, Bob can accept the channel by sending money to it
                console.log("Alice initialized the channel with "+event.returnValues.funds+" wei");
                console.log("The game is deployed at: " +event.returnValues.game);

                resp = await state.methods.accept();
                //Bob accepts the channel with 11 ETH
                var snd = await resp.send({
                    from: bobAddr,
                    gas: '2000000',
                    gasPrice: '1',
                    value: web3.utils.toWei("11", "ether")
                }).catch((error) => {console.log(error)});
                console.log("Bob accepted the proposed channel");
                called("accept", snd.gasUsed);

            }
            else if(event.event == "Event_Channel_Accepted") {
                //Bob accepted the channel with Alice
                console.log("Bob accepted the channel with alice: "+
                    event.returnValues.aliceValue+" wei, bob: "+event.returnValues.bobValue);
                //Off-Chain communication can now start 
                
                //Alice and bob play the game off chain
                //Alice hashes Rock
                //Bob hashes Paper
                //Alice commits to her hash
                //Bob commits to his hash
                //Alice now opens her hash
                //Bob refuses to open his hash

                var aliceValue = web3.utils.toWei("12", "ether");
                var bobValue = web3.utils.toWei("9", "ether");

                //Alice tries to close the channel with 12 to 9 ETH
                resp = state.methods.stopChannel(
                    aliceValue,
                    bobValue
                );
                var snd = await resp.send(
                {   from: aliceAddr,
                    gas: '2000000',
                    gasPrice: '1'
                }).catch((error) => {console.log(error)});

                console.log('Alice tried to close the channel');
                called("stopChannel", snd.gasUsed);

            //Event_Challenge_Opened is thrown when Alice calls openChallenge on the contract
            }else if (event.event == "Event_Stop_Proposed") {
                console.log("Alice proposed a stop with alice: "+
                    event.returnValues.aliceValue+" ether, bob: "+event.returnValues.bobValue);

                //Bob disputes the channel closing and starts the game on-chain
                resp = state.methods.disputeStop_StartGame();

                var snd = await resp.send(
                {   from: bobAddr,
                    gas: '4000000',
                    gasPrice: '1'
                }).catch((error) => {console.log(error)});
                called("disputeStop_StartGame", snd.gasUsed);
                console.log("Bob disputes the channel");
                
            //Event_Channel_Disputed is thrown if Bob disputes the closing of the channel with a valid signature
            } else if (event.event == "Event_Game_Started") {
                console.log("Bob started the game at: " + event.returnValues.game +
                    " with alice: "+ event.returnValues.aliceValue + " bob: "+ event.returnValues.bobValue);

                //Bob and Alice send their current state to the smart contract
                //They interact now with the smart contract on-chain

            } else if (event.event == "Event_Game_Stop_Proposed"){
                console.log("Alice proposed to stop the game");
                //Bob accepts the stop of the game
                var snd =  await state.methods.acceptStopGame().send(
                {   from: bobAddr,
                    gas: '2000000',
                    gasPrice: '1'
                }).catch((error) => {console.log(error)});
                console.log("Bob accepted the game stop");
                called("acceptStopGame", snd.gasUsed);
                
            }else if (event.event == "Event_Game_Stop_Accepted"){
                console.log("The Game was stopped with alice:" + event.returnValues.aliceValue 
                    + " bob: " + event.returnValues.bobValue )

                //Alice closes the state channel
                var snd =  await state.methods.payout().send(
                {   from: aliceAddr,
                    gas: '2000000',
                    gasPrice: '1'
                }).catch((error) => {console.log(error)});
                console.log("ALice called Payout");
                called("payout", snd.gasUsed);

            //Event_Payout is thrown whenever Alice closed the channel
            } else if (event.event == "Event_Payout") {
                console.log("Channel closed successful with alice: "
                    +event.returnValues.aliceValue+" ether, bob: "+event.returnValues.bobValue);
                console.log("Before Execution: Alice: " + aliceMoney + " Bob: " +bobMoney);
                var aliceAfter = await web3.eth.getBalance(aliceAddr);
                var bobAfter  = await web3.eth.getBalance(bobAddr);
                console.log("After Execution: Alice: " + aliceAfter + " Bob: " + bobAfter);
                var diffB = bobAfter -bobMoney;
                console.log("Difference for Bob: "+ diffB);
                overview();
                process.exit();
            } else {
                console.log("Unknown Event: "+event.event);
            }
        } else {
            console.log(error);
            console.log("Exiting");
            process.exit();
        }
    }));
}

// load web3, this assumes a running geth/parity instance
const Web3 = require('web3');
const Personal = require('web3-eth-personal');
var net = require('net');
var web3;
var personal;
if (typeof web3 !== 'undefined') {
  web3 = new Web3(web3.currentProvider);
} else {
  // set the provider you want from Web3.providers
  web3 = new Web3(Web3.givenProvider || new Web3.providers.WebsocketProvider("ws://localhost:8545"));
  var web3 = new Web3('/tmp/geth.ipc', net); // same output as with option below
  //personal = new Personal(Web3.givenProvider || new Web3.providers.WebsocketProvider("ws://localhost:8545"));
}
/*
if (!(typeof web3 !== 'undefined') || !(typeof personal !== 'undefined') )
{
    console.log("Could not load web3");
    process.exit();
}
*/

const fs = require('fs');
const exec = require('child_process').execSync;
var aliceAddr;
var bobAddr;
web3.eth.getAccounts(async function(error, result) {
    if(error != null)
        console.log("Couldn't get accounts: "+ error);
    aliceAddr = result[0];
    bobAddr = result[1];
    gasPrice = web3.utils.toWei("4", "gwei");
    var block = web3.eth.getBlock("latest");
    console.log('account 1: '+aliceAddr);
    console.log('account 2: '+bobAddr);
    var timeoutInSec = 15000;

    web3.eth.personal.unlockAccount(aliceAddr, "",timeoutInSec);
    web3.eth.personal.unlockAccount(bobAddr, "",timeoutInSec);

    //preload bobs account with 13 ETH
    await web3.eth.sendTransaction({
        from: aliceAddr, 
        to: bobAddr, 
        value: web3.utils.toWei("13", "ether"), function(err, transactionHash) {
            if (err)
                console.log(err);
        }});

    aliceMoney = await web3.eth.getBalance(aliceAddr);
    bobMoney = await web3.eth.getBalance(bobAddr);

    deployGame();
});
