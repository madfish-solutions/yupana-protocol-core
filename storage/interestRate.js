const { alice } = require("../scripts/sandbox/accounts");
const interestLambda = require("../build/lambdas/interestLambda.json");

module.exports = {
  admin: alice.pkh,
  kinkF: "0",
  baseRateF: "0",
  multiplierF: "0",
  jumpMultiplierF: "0",
  reserveFactorF: "0",
  lastUpdTime: "2021-08-20T09:06:50Z",
  utilLambda: interestLambda.bytes,
};
