const { MichelsonMap } = require("@taquito/michelson-encoder");
const Factory = artifacts.require("Factory");
const Controller = artifacts.require("Controller");

module.exports = async function (deployer, network) {
  // if (network == "development") return;

  const ControllerInstance = await Controller.deployed();
  const storage = {
    tokenList: new MichelsonMap(),
    owner: "tz1WBSTvfSC58wjHGsPeYkcftmbgscUybNuk",
    admin: ControllerInstance.address,
    tokenLambdas: new MichelsonMap(),
    useLambdas: new MichelsonMap(),
  };
  await deployer.deploy(Factory, storage);
};
