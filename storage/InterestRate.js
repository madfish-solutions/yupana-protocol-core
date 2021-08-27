const { MichelsonMap } = require("@taquito/michelson-encoder");
const { alice } = require("../scripts/sandbox/accounts");

const rateStorage = {
  admin: alice.pkh,
  yToken: alice.pkh,
  kickRate: "0",
  baseRate: "0",
  multiplier: "0",
  jumpMultiplier: "0",
  reserveFactor: "0",
};


module.exports = {
  storage: rateStorage,
  rateLambdas: MichelsonMap.fromLiteral({}),
};
