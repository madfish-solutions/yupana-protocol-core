const { alice } = require("../scripts/sandbox/accounts");
const { MichelsonMap } = require("@taquito/michelson-encoder");

// module.exports = {
//   lastDate: "2021-08-20T09:06:50Z",
//   lastPrice: '5552157',
//   returnAddress: alice.pkh,
// };

module.exports = {
  assetCodes: [],
  assetMap: MichelsonMap.fromLiteral({}),
  numDataPoints: '0',
  oracleContract: alice.pkh
};
