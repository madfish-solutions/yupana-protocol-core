const { MichelsonMap } = require("@taquito/michelson-encoder");
const { accounts } = require("../scripts/sandbox/accounts");
const { functions } = require("../storage/Functions");
const { execSync } = require("child_process");

const Factory = artifacts.require("Factory");
const Controller = artifacts.require("Controller");

function getLigo(isDockerizedLigo) {
  let path = "ligo";
  if (isDockerizedLigo) {
    path = "docker run -v $PWD:$PWD --rm -i ligolang/ligo:next";
    try {
      execSync(`${path}  --help`);
    } catch (err) {
      path = "ligo";
      execSync(`${path}  --help`);
    }
  } else {
    try {
      execSync(`${path}  --help`);
    } catch (err) {
      path = "docker run -v $PWD:$PWD --rm -i ligolang/ligo:next";
      execSync(`${path}  --help`);
    }
  }
  return path;
}

module.exports = async function (deployer, network) {
  tezos.setProvider({
    config: {
      confirmationPollingTimeoutSecond: 500,
    },
  });
  // if (network == "development") return;
  const ControllerInstance = await Controller.deployed();

  const storage = {
    tokenList: new MichelsonMap(),
    owner: accounts[0],
    admin: ControllerInstance.address,
    tokenLambdas: new MichelsonMap(),
    useLambdas: new MichelsonMap(),
  };
  await deployer.deploy(Factory, storage);
  const factoryInstance = await Factory.deployed();

  let ligo = getLigo(true);

  for (tokenFunction of functions.token) {
    const stdout = execSync(
      `${ligo} compile-parameter --michelson-format=json $PWD/contracts/main/Factory.ligo main 'SetTokenFunction(record index =${tokenFunction.index}n; func =${tokenFunction.name}; end)'`,
      { maxBuffer: 1024 * 500 }
    );
    const operation = await tezos.contract.transfer({
      to: factoryInstance.address,
      amount: 0,
      parameter: {
        entrypoint: "setTokenFunction",
        value: JSON.parse(stdout.toString()).args[0].args[0],
      },
    });
    await operation.confirmation();
  }

  for (useFunction of functions.use) {
    const stdout = execSync(
      `${ligo} compile-parameter --michelson-format=json $PWD/contracts/main/Factory.ligo main 'SetUseFunction(record index =${useFunction.index}n; func = ${useFunction.name}; end)'`,
      { maxBuffer: 1024 * 500 }
    );
    const operation = await tezos.contract.transfer({
      to: factoryInstance.address,
      amount: 0,
      parameter: {
        entrypoint: "setUseFunction",
        value: JSON.parse(stdout.toString()).args[0].args[0],
      },
    });
    await operation.confirmation();
  }
};
