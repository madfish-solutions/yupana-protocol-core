const { MichelsonMap } = require("@taquito/michelson-encoder");

module.exports = {
  totalSupplyF: "0",
  ledger: MichelsonMap.fromLiteral({}),
};
