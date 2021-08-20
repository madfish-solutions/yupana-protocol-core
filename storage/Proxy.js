const { MichelsonMap } = require("@taquito/michelson-encoder");
const { alice } = require("../scripts/sandbox/accounts");

const proxyStorage = {
  admin: alice.pkh,
  oracle: alice.pkh,
  yToken: alice.pkh,
  pairName : MichelsonMap.fromLiteral({}),
  pairId: MichelsonMap.fromLiteral({}),
};

module.exports = {
  storage: proxyStorage,
  proxyLambdas: MichelsonMap.fromLiteral({}),
};