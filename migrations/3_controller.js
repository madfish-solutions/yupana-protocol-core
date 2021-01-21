const TestController = artifacts.require("TestController");
const { accounts } = require("../scripts/sandbox/accounts");
const { MichelsonMap } = require("@taquito/michelson-encoder");

module.exports = function (deployer) {
  const storage = {
    factory: accounts[0],
    admin: "tz1WBSTvfSC58wjHGsPeYkcftmbgscUybNuk",
    qTokens: [],
    pairs: new MichelsonMap(),
  };
  deployer.deploy(TestController, storage);
};
