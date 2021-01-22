const Factory = artifacts.require("Factory");
const { accounts } = require("../scripts/sandbox/accounts");
const { MichelsonMap } = require("@taquito/michelson-encoder");

module.exports = function (deployer) {
  const storage = {
    token_list: new MichelsonMap(),
    admin: accounts[0],
    owner: "tz1WBSTvfSC58wjHGsPeYkcftmbgscUybNuk",
  };
  deployer.deploy(Factory, storage);
};
