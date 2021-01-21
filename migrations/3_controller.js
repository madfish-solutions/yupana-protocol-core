const TestController = artifacts.require("TestController");
const { accounts } = require("../scripts/sandbox/accounts");
const { MichelsonMap } = require("@taquito/michelson-encoder");

module.exports = function (deployer) {
  const storage = {
    factory: "KT1XVwgkhZH9B1Kz1nDJiwH23UekrimsjgQv",
    admin: accounts[0],
    qTokens: [],
    pairs: new MichelsonMap(),
  };
  deployer.deploy(TestController, storage);
};
