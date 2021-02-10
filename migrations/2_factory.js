const { MichelsonMap } = require("@taquito/michelson-encoder");
const { accounts } = require("../scripts/sandbox/accounts");
const Factory = artifacts.require("Factory");
const Controller = artifacts.require("Controller");

module.exports = async function (deployer, network) {
  // if (network == "development") return;
  tezos.setProvider({
    config: {
      confirmationPollingTimeoutSecond: 500,
    },
  });
  const ControllerInstance = await Controller.deployed();
  const storage = {
    tokenList: new MichelsonMap(),
    owner: accounts[0],
    admin: ControllerInstance.address,
    tokenLambdas: new MichelsonMap(),
    useLambdas: new MichelsonMap(),
  };
  await deployer.deploy(Factory, storage);
};
