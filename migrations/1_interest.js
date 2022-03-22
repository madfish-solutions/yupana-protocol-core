const { dev } = require("../scripts/sandbox/accounts");
const storage = require("../storage/interestRate");
const { migrate } = require("../scripts/helpers");

module.exports = async (tezos) => {
  const interestRateStorage = {
    ...storage,
    admin: dev.pkh,
    kinkF: "800000000000000000",
    multiplierF: "1585489599",
    jumpMultiplierF: "34563673262",
  };
  const contractAddress = await migrate(tezos, "interestRate", interestRateStorage);
  console.log(`InterestRate1 contract: ${contractAddress}`);
};
