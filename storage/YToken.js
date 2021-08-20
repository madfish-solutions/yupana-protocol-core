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
  closeFactor: "0",
  liqIncentive: "0",
};

module.exports = {
  storage: tokenStorage,
  tokenLambdas: MichelsonMap.fromLiteral({}),
  useLambdas: MichelsonMap.fromLiteral({}),
};
