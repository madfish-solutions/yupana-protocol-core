const { MichelsonMap } = require("@taquito/michelson-encoder");
const { accounts } = require("../scripts/sandbox/accounts");
const { accountsMap } = require('../scripts/sandbox/accounts');
const { TezosToolkit } = require("@taquito/taquito");
const { InMemorySigner } = require("@taquito/signer");
const { functions } = require("../storage/Functions");
const { execSync } = require("child_process");

const Factory = artifacts.require("Factory");
// const Controller = artifacts.require("Controller");

function getLigo(isDockerizedLigo) {
  let path = "ligo";
  if (isDockerizedLigo) {
    path = "docker run -v $PWD:$PWD --rm -i ligolang/ligo:0.11.0";
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
      path = "docker run -v $PWD:$PWD --rm -i ligolang/ligo:0.11.0";
      execSync(`${path}  --help`);
    }
  }
  return path;
}

module.exports = async function (deployer, network) {
  tezos = new TezosToolkit(tezos.rpc.url);
  const secretKey = accountsMap.get(accounts[0]);

  tezos.setProvider({
    config: {
      confirmationPollingTimeoutSecond: 5000,
    },
    signer: await InMemorySigner.fromSecretKey(secretKey),
  });

  // const ControllerInstance = await Controller.deployed();

  const storage = {
    tokenList: new MichelsonMap(),
    owner: accounts[0],
    admin: accounts[0],
    tokenLambdas: new MichelsonMap(),
    useLambdas: new MichelsonMap(),
  };
  await deployer.deploy(Factory, storage);
  const factoryInstance = await Factory.deployed();
  // Try to deploy another way
  // const factoryInstance = await tezos.contract.originate({
  //   code: JSON.parse(Factory.michelson),
  //   storage: storage,
  // });

  // await factoryInstance.confirmation();

  let ligo = getLigo(true);

  for (tokenFunction of functions.token) {
    console.log(tokenFunction.name);
    const stdout = execSync(
      `${ligo} compile-parameter --michelson-format=json $PWD/contracts/main/Factory.ligo main 'SetTokenFunction(record index =${tokenFunction.index}n; func =${tokenFunction.name}; end)'`,
      { maxBuffer: 1024 * 4000 }
    );
    const operation = await tezos.contract.transfer({
      to: factoryInstance.address,
      amount: 0,
      parameter: {
        entrypoint: "setTokenFunction",
        value: JSON.parse(stdout.toString()).args[0].args[0].args[0],
      },
    });
    await operation.confirmation();
    console.log('end');
  }
  console.log('full end1');

  for (useFunction of functions.use) {
    console.log(useFunction.name);
    const stdout = execSync(
      `${ligo} compile-parameter --michelson-format=json $PWD/contracts/main/Factory.ligo main 'SetUseFunction(record index =${useFunction.index}n; func = ${useFunction.name}; end)'`,
      { maxBuffer: 1024 * 3000 }
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
    console.log('end')
  }
  console.log('full end2');
};
