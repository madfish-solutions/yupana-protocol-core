const { MichelsonMap } = require("@taquito/michelson-encoder");
const { alice } = require("../scripts/sandbox/accounts");
// const Controller = require("../build/Controller.json");
// const controllerAddress = Controller["networks"]["development"][
//   "Controller"
// ];

module.exports = {
  tokenList: MichelsonMap.fromLiteral({}),
  owner: alice.pkh,
  admin: alice.pkh,
  tokenLambdas: MichelsonMap.fromLiteral({}),
  useLambdas: MichelsonMap.fromLiteral({}),
};
