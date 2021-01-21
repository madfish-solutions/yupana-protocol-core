const { MichelsonMap } = require("@taquito/michelson-encoder");
const truffleAssert = require("truffle-assertions");

const { accounts } = require("../scripts/sandbox/accounts");
const { revertDefaultSigner } = require("./helpers/signerSeter");
const { setSigner } = require("./helpers/signerSeter");

const Factory = artifacts.require("Factory");
const XTZ = artifacts.require("XTZ");
const TestController = artifacts.require("TestController");

contract("Factory", async () => {
  const DEFAULT = accounts[0];
  // const RECEIVER = accounts[1];
  // const LIQUIDATOR = accounts[3];

  let storage;
  let fInstance;
  let tokenInstance;
  let cInstance;

  before("setup", async () => {
    let storage2 = {
      factory: "KT1XVwgkhZH9B1Kz1nDJiwH23UekrimsjgQv",
      admin: DEFAULT,
      qTokens: [],
      pairs: new MichelsonMap(),
    };

    storage = {
      token_list: new MichelsonMap(),
      admin: "KT1GngWEfK2YRjfFGQqriVVDvEzcgzHvkc7D",
      owner: accounts[1],
    };
    // fInstance = await Factory.deployed();
    fInstance = await Factory.new(storage);
    cInstance = await TestController.new(storage2);
  });

  beforeEach("setup", async () => {
    const tokenStorage = {
      totalSupply: 100000,
      ledger: MichelsonMap.fromLiteral({
        [DEFAULT]: {
          balance: 100000,
          allowances: new MichelsonMap(),
        },
      }),
    };
    tokenInstance = await XTZ.new(tokenStorage);
    await revertDefaultSigner();
  });

  describe("launch_exchange", async () => {
    it("set a new qToken", async () => {
      console.log(tokenInstance.address);
      await fInstance.main(tokenInstance.address);

      const fStorage = await fInstance.storage();
      const value = await fStorage.token_list.get(tokenInstance.address);
      console.log(value);

      const cStorage = await cInstance.storage();
      const value2 = await cStorage.qTokens;
      console.log(value2);

      assert.notStrictEqual(value, undefined);
    });
  });
});
