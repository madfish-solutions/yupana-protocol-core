const { MichelsonMap } = require("@taquito/michelson-encoder");
const { alice } = require("../scripts/sandbox/accounts");

module.exports = {
  admin: alice.pkh,
  oracle: alice.pkh,
  yToken: alice.pkh,
  pairName: MichelsonMap.fromLiteral({}),
  pairId: MichelsonMap.fromLiteral({}),
  tokensDecimals: MichelsonMap.fromLiteral({}),
};
