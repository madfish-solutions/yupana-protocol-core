const { MichelsonMap } = require("@taquito/michelson-encoder");
const { alice } = require("../scripts/sandbox/accounts");

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

module.exports = {
  storage: controllerStorage,
  useControllerLambdas: MichelsonMap.fromLiteral({}),
};
