const { alice } = require("../scripts/sandbox/accounts");
const { MichelsonMap } = require("@taquito/michelson-encoder");
const { functions } = require("../storage/Functions");
const { execSync } = require("child_process");
const { migrate, getLigo } = require("../scripts/helpers");
const { confirmOperation } = require("../scripts/confirmation");

const controllerStorage = {
  factory: alice.pkh,
  admin: alice.pkh,
  qTokens: [],
  oraclePairs: MichelsonMap.fromLiteral({}),
  oracleStringPairs: MichelsonMap.fromLiteral({}),
  pairs: MichelsonMap.fromLiteral({}),
  accountBorrows: MichelsonMap.fromLiteral({}),
  accountTokens: MichelsonMap.fromLiteral({}),
  markets: MichelsonMap.fromLiteral({}),
  accountMembership: MichelsonMap.fromLiteral({}),
  oracle: alice.pkh,
  icontroller: "0",
};

module.exports = async (tezos) => {
  const controllerAddress = await migrate(tezos, "Controller", {
    storage: controllerStorage,
    useControllerLambdas: MichelsonMap.fromLiteral({}),
  });

  let ligo = getLigo(true);
  for (useControllerFunction of functions.useController) {
    console.log(useControllerFunction.name);
    const stdout = execSync(
      `${ligo} compile-parameter --michelson-format=json $PWD/contracts/main/Controller.ligo main 'SetUseAction(record index =${useControllerFunction.index}n; func = ${useControllerFunction.name}; end)'`,
      { maxBuffer: 1024 * 1000 }
    );
    const operation = await tezos.contract.transfer({
      to: controllerAddress,
      amount: 0,
      parameter: {
        entrypoint: "setUseAction",
        value: JSON.parse(stdout.toString()).args[0].args[0],
      },
    });
    await confirmOperation(tezos, operation.hash);
  }
  console.log(`Controller: ${controllerAddress}`);
};
