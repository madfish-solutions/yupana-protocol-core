const { dev } = require("../scripts/sandbox/accounts");
const { migrate } = require("../scripts/helpers");

module.exports = async (tezos) => {
  const contractAddress = await migrate(tezos, "interestRate", {
    admin: dev.pkh,
    yToken: alice.pkh,
    kickRateFloat: "0",
    baseRateFloat: "0",
    multiplierFloat: "0",
    jumpMultiplierFloat: "0",
    reserveFactorFloat: "0",
    lastUpdTime: "2021-08-20T09:06:50Z",
  });
  console.log(`InterestRate contract: ${contractAddress}`);
};
