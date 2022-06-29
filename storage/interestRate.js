const { alice } = require("../scripts/sandbox/accounts");
const metadata = require("./metadata/interestRateMetadata");

module.exports = {
  admin: alice.pkh,
  kinkF: "0",
  baseRateF: "0",
  multiplierF: "0",
  jumpMultiplierF: "0",
  reserveFactorF: "0",
  metadata: metadata
};
