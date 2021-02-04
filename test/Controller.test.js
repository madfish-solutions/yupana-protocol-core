const { MichelsonMap } = require("@taquito/michelson-encoder");
const truffleAssert = require("truffle-assertions");

const { accounts } = require("../scripts/sandbox/accounts");
const { revertDefaultSigner } = require("./helpers/signerSeter");
const { setSigner } = require("./helpers/signerSeter");

const Controller = artifacts.require("Controller");

let cInstance;

contract("Controller", async () => {
  const ADMIN = accounts[0];

  beforeEach("setup", async () => {
    const controllerStorage = {
      factory: "KT1XVwgkhZH9B1Kz1nDJiwH23UekrimsjgQv",
      admin: "tz1WBSTvfSC58wjHGsPeYkcftmbgscUybNuk",
      qTokens: [],
      pairs: new MichelsonMap(),
      accountBorrows: new MichelsonMap(),
      accountTokens: new MichelsonMap(),
      markets: new MichelsonMap(),
      accountMembership: new MichelsonMap(),
    };

    const fullControllerStorage = {
      storage: controllerStorage,
      useLambdas: MichelsonMap.fromLiteral({}),
    };

    cInstance = await Controller.deployed();
  });

  describe("setOracle", async () => {
    it("set new oracle", async () => {
      const qToken = "KT19DbHikPZEY2H8im1F6HkRh3waWgmbmx67";
      const oracle = "KT1Hi94gxTZAZjHaqSFEu3Y8PShsY4gF48Mt";
      await cInstance.use("setOracle", oracle, qToken);
    });
  });

  describe("register", async () => {
    it("register new contracts", async () => {
      const token = "KT1Hi94gxTZAZjHaqSFEu3Y8PShsY4gF48Mt";
      const qToken = "KT19DbHikPZEY2H8im1F6HkRh3waWgmbmx67";
      await cInstance.use("register", qToken, token);

      const cStorage = await cInstance.storage();
      const value = cStorage.storage.qTokens;
      console.log(value);
      assert.notStrictEqual(value, undefined);
    });
  });

  describe("updatePrice", async () => {
    it("upd price", async () => {
      const qToken = "KT19DbHikPZEY2H8im1F6HkRh3waWgmbmx67";
      const price = 100;
      await cInstance.use("updatePrice", price, qToken);
    });
  });

  describe("updateQToken", async () => {
    it("upd params for qToken", async () => {
      const user = "tz1WBSTvfSC58wjHGsPeYkcftmbgscUybNuk";
      const balance = 120;
      const borrow = 50;
      const exchangeRate = 10;
      await cInstance.use("updateQToken", user, balance, borrow, exchangeRate);
    });
  });

  describe("enterMarket", async () => {
    it("add to accountMembership", async () => {
      const token = "KT1Hi94gxTZAZjHaqSFEu3Y8PShsY4gF48Mt";
      await cInstance.use("enterMarket", token);
    });
  });

  describe("exitMarket", async () => {
    it("remove to accountMembership", async () => {
      const token = "KT1Hi94gxTZAZjHaqSFEu3Y8PShsY4gF48Mt";
      await cInstance.use("exitMarket", token);
    });
  });
});
