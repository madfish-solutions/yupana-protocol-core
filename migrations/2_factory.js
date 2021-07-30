const { alice } = require("../scripts/sandbox/accounts");
const { MichelsonMap } = require("@taquito/michelson-encoder");
const { functions } = require("../storage/Functions");
const { execSync } = require("child_process");
const { migrate, getLigo } = require("../scripts/helpers");
const { confirmOperation } = require("../scripts/confirmation");
const Controller = require("../build/Controller.json");

module.exports = async (tezos) => {
  const controllerAddress = await Controller["networks"]["development"][
    "Controller"
  ];
  const factoryAddress = await migrate(tezos, "Factory", {
    tokenList: MichelsonMap.fromLiteral({}),
    owner: alice.pkh,
    admin: controllerAddress,
    tokenLambdas: MichelsonMap.fromLiteral({}),
    useLambdas: MichelsonMap.fromLiteral({}),
  });

  let ligo = getLigo(true);
  for (tokenFunction of functions.token) {
    console.log(tokenFunction.name);
    const stdout = execSync(
      `${ligo} compile-parameter --michelson-format=json $PWD/contracts/main/Factory.ligo main 'SetTokenFunction(record index =${tokenFunction.index}n; func =${tokenFunction.name}; end)'`,
      { maxBuffer: 1024 * 4000 }
    );
    const operation = await tezos.contract.transfer({
      to: factoryAddress,
      amount: 0,
      parameter: {
        entrypoint: "setTokenFunction",
        value: JSON.parse(stdout.toString()).args[0].args[0].args[0],
      },
    });
    await confirmOperation(tezos, operation.hash);
  }

  for (useFunction of functions.use) {
    console.log(useFunction.name);
    const stdout = execSync(
      `${ligo} compile-parameter --michelson-format=json $PWD/contracts/main/Factory.ligo main 'SetUseFunction(record index =${useFunction.index}n; func = ${useFunction.name}; end)'`,
      { maxBuffer: 1024 * 3000 }
    );
    const operation = await tezos.contract.transfer({
      to: factoryAddress,
      amount: 0,
      parameter: {
        entrypoint: "setUseFunction",
        value: JSON.parse(stdout.toString()).args[0],
      },
    });
    await confirmOperation(tezos, operation.hash);
  }

  console.log(`Factory: ${factoryAddress}`);
};
