const { MichelsonMap } = require("@taquito/michelson-encoder");
const { accounts } = require("../scripts/sandbox/accounts");
const { functions } = require("../storage/Functions");
const { execSync } = require("child_process");
const Factory = artifacts.require("Factory");

var qToken = artifacts.require("qToken");

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

module.exports = async function (deployer) {
  const factoryInstance = await Factory.deployed();
  const storage = {
    owner: accounts[0],
    admin: accounts[0],
    token: accounts[0],
    lastUpdateTime: "2000-01-01T10:10:10.000Z",
    totalBorrows: "0",
    totalLiquid: "0",
    totalSupply: "0",
    totalReserves: "0",
    borrowIndex: "0",
    accountBorrows: MichelsonMap.fromLiteral({}),
    accountTokens: MichelsonMap.fromLiteral({}),
  };

  const fullStorage = {
    storage: storage,
    tokenLambdas: MichelsonMap.fromLiteral({}),
    useLambdas: MichelsonMap.fromLiteral({}),
  };

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

  await deployer.deploy(qToken, fullStorage);
};
