const { dev } = require("../scripts/sandbox/accounts");
const { migrate } = require("../scripts/helpers");

module.exports = async (tezos) => {
  const contractAddress = await migrate(tezos, "interestRate", {
    admin: dev.pkh,
    yToken: alice.pkh,
    kickRate: "0",
    baseRate: "0",
    multiplier: "0",
    jumpMultiplier: "0",
    reserveFactor: "0",
    lastUpdTime: "2021-08-20T09:06:50Z",
  });
  console.log(`InterestRate contract: ${contractAddress}`);
};
