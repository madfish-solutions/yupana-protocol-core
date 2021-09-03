const { MichelsonMap } = require("@taquito/michelson-encoder");

module.exports = {
  totalSupply: "0",
  ledger:  MichelsonMap.fromLiteral({}),
}
