const { MichelsonMap } = require("@taquito/michelson-encoder");
const { InMemorySigner } = require("@taquito/signer");

const { accounts } = require("../scripts/sandbox/accounts");
const { accountsMap } = require("../scripts/sandbox/accounts");

const Factory = artifacts.require("Factory");
const XTZ = artifacts.require("XTZ");
const Controller = artifacts.require("Controller");

let cInstance;
let fInstance;
let XTZInstance;

contract("Factory", async () => {
  before("setup", async () => {
    cInstance = await Controller.deployed();
    fInstance = await Factory.deployed();
  });

  beforeEach("setup", async () => {
    let XTZStorage = {
      totalSupply: 0,
      ledger: new MichelsonMap(),
    };
    XTZInstance = await XTZ.new(XTZStorage);
    console.log("Created FA1.2 token:", XTZInstance.address);
  });

  describe("launchToken", async () => {
    it("set Factory address", async () => {
      tezos.setProvider({
        signer: await InMemorySigner.fromSecretKey(
          accountsMap.get(accounts[0])
        ),
      });

      await cInstance.setFactory(fInstance.address);
      const cStorage = await cInstance.storage();
      const value = cStorage.storage.factory;
      console.log("NewFactory: ", value);
    });

    it("set a new qToken", async () => {
      await fInstance.launchToken(XTZInstance.address);

      const fStorage = await fInstance.storage();
      const value = await fStorage.tokenList.get(XTZInstance.address);
      console.log("NewToken:", value);
    });
  });
});
