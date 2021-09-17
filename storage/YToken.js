const { MichelsonMap } = require("@taquito/michelson-encoder");
const { alice } = require("../scripts/sandbox/accounts");

const tokenStorage = {
  admin: alice.pkh,
  accountInfo: MichelsonMap.fromLiteral({}),
  tokenInfo: MichelsonMap.fromLiteral({}),
  metadata: MichelsonMap.fromLiteral({}),
  tokenMetadata: MichelsonMap.fromLiteral({}),
  lastTokenId: "0",
  priceFeedProxy: alice.pkh,
  closeFactorFloat: "0",
  liqIncentiveFloat: "0",
  maxMarkets: "0",
};

module.exports = {
  storage: tokenStorage,
  tokenLambdas: MichelsonMap.fromLiteral({}),
  useLambdas: MichelsonMap.fromLiteral({}),
};
