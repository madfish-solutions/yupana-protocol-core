const { MichelsonMap } = require("@taquito/michelson-encoder");
const truffleAssert = require("truffle-assertions");

const { accounts } = require("../scripts/sandbox/accounts");
const { revertDefaultSigner } = require("./helpers/signerSeter");
const { setSigner } = require("./helpers/signerSeter");

const TestController = artifacts.require("TestController");

let cInstance;

contract("TestController", async () => {
  const ADMIN = accounts[0];

  beforeEach("setup", async () => {
    const storage = {
      factory: "KT1XVwgkhZH9B1Kz1nDJiwH23UekrimsjgQv",
      admin: ADMIN,
      qTokens: [],
      pairs: new MichelsonMap(),
    };

    cInstance = await TestController.new(storage);
  });

  describe("setFactoryAddress", async () => {
    it("set new factory address", async () => {
      const newFAddress = "KT1UQ9FBMcwzaLSqQejAcAzy3wSN8zTQvZdv";
      await cInstance.setFactory(newFAddress);

      const cStorage = await cInstance.storage();
      const value = await cStorage.factory;
      console.log(value);
      assert.notStrictEqual(value, undefined);
    });
  });

  describe("register", async () => {
    it("register new contracts", async () => {
        const token = "KT1Hi94gxTZAZjHaqSFEu3Y8PShsY4gF48Mt";
        const qToken = "KT19DbHikPZEY2H8im1F6HkRh3waWgmbmx67";
        await cInstance.register(token, qToken);

        const cStorage = await cInstance.storage();
        const value = await cStorage.qTokens;
        console.log(value);
    });
  });
});
