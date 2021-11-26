const { dev, alice } = require("../scripts/sandbox/accounts");
const { migrate } = require("../scripts/helpers");
const { confirmOperation } = require("../scripts/confirmation");
const { getLigo } = require("../scripts/helpers");
const { execSync } = require("child_process");
const { InMemorySigner } = require("@taquito/signer");

module.exports = async (tezos) => {
  const contractAddress = await migrate(tezos, "interestRate", {
    admin: dev.pkh,
    kinkF: "0",
    baseRateF: "0",
    multiplierF: "0",
    jumpMultiplierF: "0",
    reserveFactorF: "0",
    lastUpdTime: "2021-08-20T09:06:50Z",
  });

  // tezos.setProvider({
  //   signer: await InMemorySigner.fromSecretKey(dev.sk),
  // });

  // const ligo = getLigo(true);

  // const stdout = execSync(
  //   `${ligo} compile-expression pascaligo --michelson-format=json --init-file $PWD/contracts/main/interestRate.ligo 'SetCoefficients(record [kinkF = 800000000000000000n; baseRateF = 634195839n; multiplierF = 7134703196n; jumpMultiplierF = 31709791983n] )'`,
  //   { maxBuffer: 1024 * 1000 }
  // );

  // const operation = await tezos.contract.transfer({
  //   to: contractAddress,
  //   amount: 0,
  //   parameter: {
  //     entrypoint: "setCoefficients",
  //     value: JSON.parse(stdout.toString()).args[0].args[0],
  //   },
  // });
  // await confirmOperation(tezos, operation.hash);

  console.log(`InterestRate contract: ${contractAddress}`);
};
