const { MichelsonMap } = require("@taquito/michelson-encoder");
const { alice } = require("../scripts/sandbox/accounts");

const tokenStorage = {
  admin: alice.pkh,
  ledger: MichelsonMap.fromLiteral({}),
  accounts: MichelsonMap.fromLiteral({}),
  tokens: MichelsonMap.fromLiteral({}),
  metadata: MichelsonMap.fromLiteral({}),
  tokenMetadata: MichelsonMap.fromLiteral({}),
  lastTokenId: "0",
  priceFeedProxy: alice.pkh,
  closeFactorF: "0",
  liqIncentiveF: "0",
  maxMarkets: "0",
  markets: MichelsonMap.fromLiteral({}),
  borrows: MichelsonMap.fromLiteral({}),
  typesInfo: MichelsonMap.fromLiteral({}),
  threshold: "0",
};

module.exports = {
  storage: tokenStorage,
  tokenLambdas: MichelsonMap.fromLiteral({}),
  useLambdas: MichelsonMap.fromLiteral({}),
};
