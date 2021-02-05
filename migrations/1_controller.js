const Controller = artifacts.require("Controller");
const { accounts } = require("../scripts/sandbox/accounts");
const { MichelsonMap } = require("@taquito/michelson-encoder");
const { functions } = require("../storage/Functions");
const { execSync } = require("child_process");

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
  const controllerStorage = {
    factory: accounts[0],
    admin: "tz1WBSTvfSC58wjHGsPeYkcftmbgscUybNuk",
    qTokens: [],
    pairs: new MichelsonMap(),
    accountBorrows: new MichelsonMap(),
    accountTokens: new MichelsonMap(),
    markets: new MichelsonMap(),
    accountMembership: new MichelsonMap(),
  };

  const fullControllerStorage = {
    storage: controllerStorage,
    useControllerLambdas: MichelsonMap.fromLiteral({}),
  };

  await deployer.deploy(Controller, fullControllerStorage);
  const ControllerInstance = await Controller.deployed();

  let ligo = getLigo(true);

  for (useControllerFunction of functions.useController) {
    const stdout = execSync(
      `${ligo} compile-parameter --michelson-format=json $PWD/contracts/main/Controller.ligo main 'SetUseAction(record index =${useControllerFunction.index}n; func = ${useControllerFunction.name}; end)'`,
      { maxBuffer: 1024 * 500 }
    );
    const operation = await tezos.contract.transfer({
      to: ControllerInstance.address,
      amount: 0,
      parameter: {
        entrypoint: "setUseAction",
        value: JSON.parse(stdout.toString()).args[0].args[0],
      },
    });
    await operation.confirmation();
  }
};
