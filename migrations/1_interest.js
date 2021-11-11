const { dev } = require("../scripts/sandbox/accounts");
const { migrate } = require("../scripts/helpers");

module.exports = async (tezos) => {
  const contractAddress = await migrate(tezos, "interestRate", {
    admin: dev.pkh,
    yToken: alice.pkh,
    kickRateF: "0",
    baseRateF: "0",
    multiplierF: "0",
    jumpMultiplierF: "0",
    reserveFactorF: "0",
    lastUpdTime: "2021-08-20T09:06:50Z",
  });
  console.log(`InterestRate contract: ${contractAddress}`);
};
