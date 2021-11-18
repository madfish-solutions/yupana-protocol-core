const { migrate } = require("../scripts/helpers");
const { MichelsonMap } = require("@taquito/michelson-encoder");

module.exports = async (tezos) => {
  const contractAddress = await migrate(tezos, "fa12", {
    totalSupplyF: "0",
    ledger: MichelsonMap.fromLiteral({}),
  });

  console.log(`Fa12 contract: ${contractAddress}`);
};
