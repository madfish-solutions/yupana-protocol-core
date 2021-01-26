const { MichelsonMap } = require("@taquito/michelson-encoder");

var qToken = artifacts.require("qToken");

module.exports = async function (deployer) {
  const now = Date.parse((await tezos.rpc.getBlockHeader()).timestamp);
  const storage = {
    owner: accounts[0],
    admin: accounts[0],
    token: accounts[0],
    lastUpdateTime: "2000-01-01T10:10:10.000Z",
    totalBorrows: "0",
    totalLiquid: "0",
    totalSupply: "0",
    totalReserves: "0",
    borrowIndex: "0",
    accountBorrows: MichelsonMap.fromLiteral({}),
    accountTokens: MichelsonMap.fromLiteral({}),
  };
  await deployer.deploy(qToken, storage);
};
