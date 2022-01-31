const { dev } = require("../scripts/sandbox/accounts");
const { migrate } = require("../scripts/helpers");

module.exports = async (tezos) => {
  return;
  const contractAddress = await migrate(tezos, "interestRate", {
    admin: dev.pkh,
    kinkF: "800000000000000000",
    baseRateF: "0",
    multiplierF: "1585489599",
    jumpMultiplierF: "34563673262",
    reserveFactorF: "0",
    lastUpdTime: "2021-08-20T09:06:50Z",
  });
  console.log(`InterestRate1 contract: ${contractAddress}`);
};
