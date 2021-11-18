const { dev, alice } = require("../scripts/sandbox/accounts");
const { migrate } = require("../scripts/helpers");
const { MichelsonMap } = require("@taquito/michelson-encoder");

module.exports = async (tezos) => {
  const contractAddress = await migrate(tezos, "priceFeed", {
    admin: dev.pkh,
    oracle: alice.pkh,
    yToken: alice.pkh,
    pairName : MichelsonMap.fromLiteral({}),
    pairId: MichelsonMap.fromLiteral({}),
  });

  console.log(`Proxy contract: ${contractAddress}`);
};
