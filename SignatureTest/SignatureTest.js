const utils = require('ethereumjs-util');
const abi = require('ethereumjs-abi');

var aliceMoney;
var bobMoney;

let gasUsedTotal = 0;
let functionCalls = [];
let gasPrice = 0;

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

function genHash(args)
{
    console.log("adsf"+args);
    const msgHash = "0x" + abi.soliditySHA3(
        args
    ).toString("hex");
    return msgHash;
}

//Generates a signature for a specific user
function genSig(msgHash, address) {
    //msgHash = genHash(args);
    //let sign = web3.eth.accounts.sign(msgHash,web3.eth.accounts.privateKeyToAccount(address));
    let sign = web3.eth.personal.sign(msgHash, address, "");
    return sign;
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
function deployUniPayment() {
    var upc = getContract("Signature");
    var contract = new web3.eth.Contract(JSON.parse(upc.abi), {from: aliceAddr, data: upc.code, gas: '200000000'});
    var cntr = contract.deploy({
         data: upc.code,
         value: web3.utils.toWei("10", "ether")
     });
    cntr.estimateGas(function(err, gas){
        called("deployCost", gas);
    });
    cntr.send(
        {   from: aliceAddr,
            gas: '2000000',
            gasPrice: '3',
            value: web3.utils.toWei("10", "ether")}
        , function (e, contract){
           if(e){
            console.log(e);
           }
           if (typeof contract.address !== 'undefined') {
               console.log('Contract mined! address: ' + contract.address + ' transactionHash: ' + contract.transactionHash);
               
           }
     }).then(function(newContractInstance){
        console.log('Signature deployed at ' + newContractInstance.options.address);
        runTests(newContractInstance);
    });
}

//Helper function to add a timeout
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

//Runs the tests, acts as one run through the protocol
function runTests(upc) {
    // setup Unidirectional Payment Channel watcher with async callbacks
    var events = upc.events.allEvents({fromBlock: 0, toBlock: 'latest'},
        (async function(error, event) {
        if (!error) {
            //console.log(event.event);

            if(event.event == "Event_Tick") {
                sleep(100);
                _hash = await web3.utils.soliditySha3("1234");
                _hash2 = await web3.utils.sha3("1234"); 
                _hash3 = await web3.utils.sha3("1234", aliceAddr);                
                _hash4 = await web3.utils.sha3("1234",{type: 'address', value: aliceAddr});
                _hash5 = await web3.utils.soliditySha3("1234", aliceAddr);
                _hash6 = await web3.utils.soliditySha3('1234',{type: 'address', value: aliceAddr});
                _hash7 = await web3.utils.soliditySha3({type: 'address', value: aliceAddr});
                _hash8 = await web3.utils.soliditySha3(aliceAddr);
                _hash9 = await web3.utils.sha3(aliceAddr);

                hash = _hash8;
                sig = genSig(hash,aliceAddr);
                console.log(sig);

                console.log("piep: " +hash);
                console.log("0:" + _hash);
                console.log("1:" + _hash2);
                console.log("2:" + _hash3);
                console.log("3:" + _hash4);
                console.log("4:" + _hash5);
                console.log("5:" + _hash6);
                console.log("6:" + _hash7);
                console.log("7:" + _hash8);
                console.log("8:" + _hash9);
                //console.log("f:" + _hash6);
                //Bob disputes the channel closing by sending a valid signature for 8 ether
                resp = upc.methods.init(
                    aliceAddr,
                    aliceAddr
                );
                snd = await resp.send(
                {   from: aliceAddr,
                    gas: '2000000',
                    gasPrice: '1'
                }).catch((error) => {console.log(error)});
                called("init", snd.gasUsed);
            }else if (event.event == "Event_Tock") {
                _hash8 = await web3.utils.soliditySha3(aliceAddr);
                hash = _hash8;
                sig = await genSig(hash,aliceAddr);
                console.log(sig);
                //sig = sig.signature;

                var r = `${sig.slice(0, 66)}`
                var s = `0x${sig.slice(66, 130)}`
                //var v = `0x${sig.slice(130, 132)}`
                var v = sig.slice(130, 132);
                console.log(r,s,v);
                
                resp = upc.methods.verify(
                    hash,
                    v,r,s,
                    aliceAddr
                );
                /*
                resp = upc.methods.verify(
                    hash,
                    sig.v,sig.r,sig.s,
                    aliceAddr
                );*/
                //resp = upc.methods.asdf();
                snd = await resp.send(
                {   from: aliceAddr,
                    gas: '2000000',
                    gasPrice: '1'
                }).catch((error) => {console.log(error)});
                called("init", snd.gasUsed);

                

                
            }else if(event.event == "Event_Data"){
                console.log("Data: "+event.returnValues.a+
                    " : "+event.returnValues.data);

            }else {
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
    var block = web3.eth.getBlock("latest");
    console.log('account 1: '+aliceAddr);
    gasPrice = web3.utils.toWei("4", "gwei");
    var timeoutInSec = 15000;

    web3.eth.personal.unlockAccount(aliceAddr, "",timeoutInSec);

    aliceMoney = await web3.eth.getBalance(aliceAddr);

    deployUniPayment();
});
