const { alice } = require("../scripts/sandbox/accounts");
const { migrate } = require("../scripts/helpers");

module.exports = async (tezos) => {
  const now = new Date((await tezos.rpc.getBlockHeader()).timestamp);
  const startTimestamp = new Date(now.setSeconds(now.getSeconds()));

  const oracleAddress = await migrate(tezos, "getOracle", {
    lastDate: startTimestamp,
    lastPrice: "7612934",
    returnAddress: alice.pkh,
  });
  console.log("Oracle: ", oracleAddress);
};
