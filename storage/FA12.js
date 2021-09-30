const { MichelsonMap } = require("@taquito/michelson-encoder");

module.exports = {
  totalSupplyFloat: "0",
  ledger: MichelsonMap.fromLiteral({}),
};
