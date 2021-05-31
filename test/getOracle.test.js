const { MichelsonMap } = require("@taquito/michelson-encoder");
const { InMemorySigner } = require("@taquito/signer");
const { TezosToolkit } = require("@taquito/taquito");

const { accounts } = require("../scripts/sandbox/accounts");
const { accountsMap } = require("../scripts/sandbox/accounts");
const { rejects, ok, strictEqual } = require("assert");

const { confirmOperation } = require('../helpers/confirmation');

const Controller = artifacts.require("Controller");
const XTZ = artifacts.require("XTZ");
const Factory = artifacts.require("Factory");
const qT = artifacts.require("qToken");
const getOracle = artifacts.require("getOracle");

let cInstance;
let fInstance;
let XTZInstance;
let qTokenAddress;

var fa = [];
var qTokens = [];

contract("Controller", async () => {
  before("setup1", async () => {
    tezos = new TezosToolkit(tezos.rpc.url);
    tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])));
    cInstance = await tezos.contract.at((await Controller.deployed()).address);
    fInstance = await tezos.contract.at((await Factory.deployed()).address);
		gInstance = await tezos.contract.at((await getOracle.deployed()).address);

    let operation = await tezos.contract.transfer({
      to: accounts[2],
      amount: 50000000,
      mutez: true,
    });
    await confirmOperation(tezos, operation.hash)

    console.log("acc0", await tezos.tz.getBalance(accounts[0]));

    console.log("acc2", await tezos.tz.getBalance(accounts[2]));

    operation = await cInstance.methods.setFactory(fInstance.address).send();
    await confirmOperation(tezos, operation.hash)

    operation = await gInstance.methods.updReturnAddressOracle(cInstance.address).send();
    await confirmOperation(tezos, operation.hash)

    var cStorage = await cInstance.storage();
    var value = cStorage.storage.factory;
    console.log("NewFactory: ", value);

    cStorage = await gInstance.storage();
    value = cStorage.returnAddress;
    console.log("NewAddress Controller: ", value);
	});

	async function setup2 (name) {
    let XTZStorage = {
      totalSupply: 0,
      ledger: MichelsonMap.fromLiteral({
        [accounts[0]]: {
          balance: 15000,
          allowances: MichelsonMap.fromLiteral({}),
        },
        [accounts[1]]: {
          balance: 15000,
          allowances: MichelsonMap.fromLiteral({}),
        },
        [accounts[2]]: {
          balance: 15000,
          allowances: MichelsonMap.fromLiteral({}),
        },
      }),
    };
    XTZInstance = await tezos.contract.at((await XTZ.new(XTZStorage)).address);

    fa.push(XTZInstance.address);
    console.log("Created FA1.2 token:", XTZInstance.address);

    const operation = await fInstance.methods.launchToken(name, XTZInstance.address).send();
    await confirmOperation(tezos, operation.hash)
    const fStorage = await fInstance.storage();
    qTokenAddress = await fStorage.tokenList.get(XTZInstance.address);
    qTokens.push(qTokenAddress);

    var cStorage = await cInstance.storage();
    var value = cStorage.storage.oracleStringPairs.get(name);
    console.log("check1: ", await value);

    cStorage = await cInstance.storage();
    value = cStorage.storage.oraclePairs.get(qTokenAddress);
    console.log("check2: ", await value);


    console.log("Created new qToken:", qTokenAddress);

    const operation2 = await XTZInstance.methods.approve(qTokenAddress, 500).send();
    await confirmOperation(tezos, operation2.hash)

    tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[1])));
    const operation3 = await XTZInstance.methods.approve(qTokenAddress, 500).send();
    await confirmOperation(tezos, operation3.hash)

    tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[2])));
    const operation4 = await XTZInstance.methods.approve(qTokenAddress, 500).send();
    await confirmOperation(tezos, operation4.hash)
    tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])));
  }

  describe("setOracle", async () => {
    it("set new oracle colled by admin", async () => {
      await setup2("XTZ-USD"); // 0
      tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])));

      const oracle = gInstance.address;
      const operation = await cInstance.methods.useController("setOracle", oracle).send();
      await confirmOperation(tezos, operation.hash)

      const oracleStorage = await cInstance.storage();
      const value = await oracleStorage.storage.oracle;
      console.log("NewOracle:", await value);
    });

    it("send to oracle", async () => {
      tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])));

      var operation = await cInstance.methods.useController("sendToOracle", qTokenAddress).send();
      await confirmOperation(tezos, operation.hash)

      const oracleStorage = await cInstance.storage();
      const value = await oracleStorage.storage.markets.get(qTokenAddress);
      console.log("LastPrice after upd:", (value.lastPrice).toString());
    });
  });
});
