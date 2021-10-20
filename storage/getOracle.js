const { alice } = require("../scripts/sandbox/accounts");
const { MichelsonMap } = require("@taquito/michelson-encoder");

module.exports = {
  tokenInfo: MichelsonMap.fromLiteral({}),
  returnAddress: alice.pkh,
};

// module.exports = {
//   assetCodes: [],
//   assetMap: MichelsonMap.fromLiteral({}),
//   numDataPoints: '0',
//   oracleContract: alice.pkh
// };
