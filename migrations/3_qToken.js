const { MichelsonMap } = require("@taquito/michelson-encoder");
const { functions } = require("../storage/Functions");
const { accounts } = require("../scripts/sandbox/accounts");
const { accountsMap } = require('../scripts/sandbox/accounts');
const { TezosToolkit } = require("@taquito/taquito");
const { InMemorySigner } = require("@taquito/signer");
const { execSync } = require("child_process");
const Factory = artifacts.require("Factory");

const XTZ = artifacts.require("XTZ");
const Controller = artifacts.require("Controller");

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
  if (network == "development") return;
  const secretKey = accountsMap.get(accounts[0]);

  tezos.setProvider({
    config: {
      confirmationPollingTimeoutSecond: 2500,
    },
    signer: await InMemorySigner.fromSecretKey(secretKey),
  });
  // const factoryInstance = await Factory.deployed();
  // const ControllerInstance = await Controller.deployed();
  // await ControllerInstance.setFactory(factoryInstance.address);
  // const storage = {
  //   owner: accounts[0],
  //   admin: accounts[0],
  //   token: accounts[0],
  //   lastUpdateTime: "2000-01-01T10:10:10.000Z",
  //   totalBorrows: "0",
  //   totalLiquid: "0",
  //   totalSupply: "0",
  //   totalReserves: "0",
  //   borrowIndex: "0",
  //   accountBorrows: MichelsonMap.fromLiteral({}),
  //   accountTokens: MichelsonMap.fromLiteral({}),
  // };

  // const fullStorage = {
  //   storage: storage,
  //   tokenLambdas: MichelsonMap.fromLiteral({}),
  //   useLambdas: MichelsonMap.fromLiteral({}),
  // };

  // let ligo = getLigo(true);

  // for (tokenFunction of functions.token) {
  //   const stdout = execSync(
  //     `${ligo} compile-parameter --michelson-format=json $PWD/contracts/main/Factory.ligo main 'SetTokenFunction(record index =${tokenFunction.index}n; func =${tokenFunction.name}; end)'`,
  //     { maxBuffer: 1024 * 500 }
  //   );
  //   const operation = await tezos.contract.transfer({
  //     to: factoryInstance.address,
  //     amount: 0,
  //     parameter: {
  //       entrypoint: "setTokenFunction",
  //       value: JSON.parse(stdout.toString()).args[0].args[0],
  //     },
  //   });
  //   await operation.confirmation();
  // }
  // for (useFunction of functions.use) {
  //   const stdout = execSync(
  //     `${ligo} compile-parameter --michelson-format=json $PWD/contracts/main/Factory.ligo main 'SetUseFunction(record index =${useFunction.index}n; func = ${useFunction.name}; end)'`,
  //     { maxBuffer: 1024 * 500 }
  //   );
  //   const operation = await tezos.contract.transfer({
  //     to: factoryInstance.address,
  //     amount: 0,
  //     parameter: {
  //       entrypoint: "setUseFunction",
  //       value: JSON.parse(stdout.toString()).args[0].args[0],
  //     },
  //   });
  //   await operation.confirmation();
  // }

  var XTZInstance = null;
  // if (network == "development") {
  const xtzStorage = {
    totalSupply: 0,
    ledger: MichelsonMap.fromLiteral({}),
  };
  await deployer.deploy(XTZ, xtzStorage);
  XTZInstance = await XTZ.deployed();
  // }

  // await factoryInstance.launchToken(XTZInstance.address);
};
