const { MichelsonMap } = require("@taquito/michelson-encoder");
const { InMemorySigner } = require("@taquito/signer");
const { TezosToolkit } = require("@taquito/taquito");

const { alice, bob, carol, peter } = require("../scripts/sandbox/accounts");

const { strictEqual } = require("assert");

const { Factory } = require("../test/utills/Factory");
const { Controller } = require("../test/utills/Controller");
const { Utils } = require("../test/utills/Utils");

const { migrate } = require("../scripts/helpers");

const env = require("../env");
const { confirmOperation } = require("../scripts/confirmation");

async function getTezosFor(secretKey) {
  const networkConfig = env.networks[defaultNetwork];
  let tz = new TezosToolkit(networkConfig.rpc);
  tz.setProvider({ signer: new InMemorySigner(secretKey) });
  return tz;
}

describe("Factory tests", async () => {
  let tezos;
  let factory;
  let controller;
  let factoryContractAddress;
  let controllerContractAddress;
  let tzAlice, tzBob, tzCarol;
  let XTZInstance;

  before("setup Factory", async () => {
    tzAlice = await getTezosFor(alice.sk);
    tzBob = await getTezosFor(bob.sk);
    tzCarol = await getTezosFor(carol.sk);

    tezos = await Utils.initTezos();
    factory = await Factory.originate(tezos);
    controller = await Controller.originate(tezos);

    controllerContractAddress = controller.contract.address;
    factoryContractAddress = factory.contract.address;

    tezos = await Utils.setProvider(tezos, alice.sk);

    let operation = await tezos.contract.transfer({
      to: carol.pkh,
      amount: 50000000,
      mutez: true,
    });
    await confirmOperation(tezos, operation.hash);

    operation = await tezos.contract.transfer({
      to: peter.pkh,
      amount: 50000000,
      mutez: true,
    });
    await confirmOperation(tezos, operation.hash);
  });

  it("set Factory admin", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await factory.setFactoryAdmin(controllerContractAddress);
    await factory.updateStorage();
    strictEqual(factory.storage.admin, controllerContractAddress);
  });

  it("set Factory address", async () => {
    await controller.setFactory(factoryContractAddress);
    await controller.updateStorage();
    strictEqual(controller.storage.storage.factory, factoryContractAddress);
  });

  it("set a new qToken", async () => {
    XTZInstance = await migrate(tezos, "XTZ", {
      totalSupply: 0,
      ledger: MichelsonMap.fromLiteral({}),
    });
    console.log("Created new FA1.2 token:", XTZInstance);

    await factory.launchToken(XTZInstance, "XTZ-BTC");
    await factory.updateStorage();
    if ((await factory.storage.tokenList.get(XTZInstance)) != undefined)
      console.log("Token found");
    else console.log("Token not found");
  });
});
