const getOracle = artifacts.require("getOracle");
const { accounts } = require("../scripts/sandbox/accounts");

module.exports = async (deployer, _network) => {
	const now = new Date((await tezos.rpc.getBlockHeader()).timestamp);
	const startTimestamp = new Date(now.setSeconds(now.getSeconds()));

	await deployer.deploy(getOracle, {
    lastDate: startTimestamp,
    lastPrice: "7612934",
    returnAddress: accounts[0],
    qq: "0",
  });
};
