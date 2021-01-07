const { MichelsonMap } = require("@taquito/michelson-encoder");
const { accounts } = require("../scripts/sandbox/accounts");

const XTZ = artifacts.require("XTZ");
const Controller = artifacts.require("Controller")

module.exports = async function (deployer) {

  /////////////////

  // const DEFAULT = accounts[0];
  //
  // const defaultsBalance = 1500;
  // const defaultsAmt = 15;
  //
  // const totalSupply = 50000;
  //
  // const storage = {
  //   ledger: MichelsonMap.fromLiteral({
  //     [DEFAULT]: {
  //       balance: defaultsBalance,
  //       allowances: MichelsonMap.fromLiteral({
  //         [DEFAULT]: defaultsAmt,
  //       }),
  //     },
  //   }),
  //   totalSupply: totalSupply,
  // };
  // await deployer.deploy(XTZ, storage)
  //
  // console.log("XTZ address", XTZ.address)


  ////////////////

  //
  // let accBorrows = new MichelsonMap()
  // accBorrows.set({
  //   user: accounts[0],
  //   token: accounts[1],
  // }, 0);
  //
  // let accTokens = new MichelsonMap()
  // accTokens.set({
  //   user: accounts[0],
  //   token: accounts[1],
  // }, 0);
  //
  // const storage = {
  //   factory: accounts[0],
  //   admin: accounts[1],
  //   qTokens: [],
  //   pairs: MichelsonMap.fromLiteral({
  //     [accounts[0]]: accounts[0],
  //   }),
  //   accountBorrows: accBorrows,
  //   accountTokens: accTokens,
  //   markets: MichelsonMap.fromLiteral({
  //     [accounts[0]]: {
  //       collateralFactor: 0,
  //       lastPrice: 0,
  //       oracle: accounts[0],
  //       exchangeRate: 0,
  //     },
  //   }),
  //   accountMembership: MichelsonMap.fromLiteral({
  //     [accounts[0]]: [],
  //   }),
  // };
  //
  // await deployer.deploy(Controller, storage);
};
