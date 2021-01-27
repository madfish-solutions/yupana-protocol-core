const Factory = artifacts.require("Factory");
const { accounts } = require("../scripts/sandbox/accounts");
const { MichelsonMap } = require("@taquito/michelson-encoder");

module.exports = function (deployer) {
  const storage = {
    tokenList: new MichelsonMap(),
    owner: "tz1WBSTvfSC58wjHGsPeYkcftmbgscUybNuk",
    admin: accounts[0],
    tokenLambdas: new MichelsonMap(),
    useLambdas: new MichelsonMap(),
  };
  deployer.deploy(Factory, storage);
};
