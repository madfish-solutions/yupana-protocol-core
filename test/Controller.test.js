const { MichelsonMap } = require("@taquito/michelson-encoder");
const { InMemorySigner } = require("@taquito/signer");
const { TezosToolkit } = require("@taquito/taquito");

const { accounts } = require("../scripts/sandbox/accounts");
const { accountsMap } = require("../scripts/sandbox/accounts");
const { revertDefaultSigner } = require("./helpers/signerSeter");
const { setSigner } = require("./helpers/signerSeter");

const Controller = artifacts.require("Controller");
const XTZ = artifacts.require("XTZ");
const Factory = artifacts.require("Factory");
const qT = artifacts.require("qToken");

let cInstance;
let fInstance;
let XTZInstance;
let qTokenAddress;

var fa = [];
var qTokens = [];

contract("Controller", async () => {
  before("setup1", async () => {
    console.log(tezos.rpc.url);
    tezos = new TezosToolkit(tezos.rpc.url);
    tezos.setSignerProvider(new InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])));

    cInstance = await tezos.contract.at((await Controller.deployed()).address);
    fInstance = await tezos.contract.at((await Factory.deployed()).address);
    console.log("Need address", fInstance.address);

    console.log("CI: ",cInstance);

    await cInstance.methods.setFactory(fInstance.address).send();
    const cStorage = await cInstance.storage();
    console.log("CS: ",cStorage);
    const value = cStorage.storage.factory;
    console.log("NewFactory: ", value);
  });

  beforeEach("setup2", async () => {
    let XTZStorage = {
      totalSupply: 0,
      ledger: MichelsonMap.fromLiteral({
        [accounts[0]]: {
          balance: 15000,
          allowances: MichelsonMap.fromLiteral({}),
        },
        [accounts[1]]: {
          balance: 15000,
          allowances: MichelsonMap.fromLiteral({}),
        },
      }),
    };
    console.log("ky");
    XTZInstance = await XTZ.new(XTZStorage);

    fa.push(XTZInstance.address);
    console.log("Created FA1.2 token:", XTZInstance.address);

    console.log("FI: ", fInstance);

    await fInstance.methods.launchToken(XTZInstance.address).send();
    console.log("ky2");

    const fStorage = await fInstance.storage();
    console.log("fS: ", fStorage);
    console.log("ky3");
    qTokenAddress = await fStorage.tokenList.get(XTZInstance.address);
    console.log("ky4");
    qTokens.push(qTokenAddress);
    console.log("New qToken:", qTokenAddress);
    await XTZInstance.approve(qTokenAddress, 2000);
    console.log("ky5");

    await setSigner(accounts[1]);
    console.log("ky6");
    await XTZInstance.approve(qTokenAddress, 2000);
    console.log("ky7");
    await revertDefaultSigner();
    console.log("ky8");
  });

  describe("setOracle", async () => {
    it("set new oracle", async () => {
      const oracle = "KT1Hi94gxTZAZjHaqSFEu3Y8PShsY4gF48Mt";
      await cInstance.methods.useController("setOracle", oracle, qTokenAddress).send();
      const oracleStorage = await cInstance.storage();
      const value = await oracleStorage.storage.markets.get(qTokenAddress);
      console.log("NewOracle:", await value.oracle);
    });
  });

  describe("safeMint", async () => {
    it("Safe Mint 140 for account 0", async () => {
      var amount = 140;
      await cInstance.methods.useController("safeMint", amount, qTokenAddress);

      let token = await qT.at(qTokenAddress);
      let res = await token.storage();
      console.log(
        "Account Tokens amount: ",
        await res.storage.accountTokens.get(accounts[0])
      );

      let x = await XTZ.at(fa[0]);
      let xRes = await x.storage();
      let xB = await xRes.ledger.get(accounts[0]);
      console.log("Balance:", await xB.balance);
    });
  });

  describe("safeMint2", async () => {
    it("Safe Mint 150 for account 1", async () => {
      await setSigner(accounts[1]);

      var amount = 150;
      await cInstance.methods.useController("safeMint", amount, qTokenAddress);

      let token = await qT.at(qTokenAddress);
      let res = await token.storage();
      console.log(
        "Account Tokens amount: ",
        await res.storage.accountTokens.get(accounts[1])
      );

      let x = await XTZ.at(fa[0]);
      let xRes = await x.storage();
      let xB = await xRes.ledger.get(accounts[1]);
      console.log("Balance:", await xB.balance);
      await revertDefaultSigner();
    });
  });

  describe("safeBorrow", async () => {
    it("Safe Borrow 10 for account 0", async () => {
      var amount = 10;

      await cInstance.useController(
        "safeBorrow",
        qTokens[qTokens.length - 3],
        amount,
        qTokens[qTokens.length - 2]
      );

      let token = await qT.at(qTokens[qTokens.length - 2]);
      let res = await token.storage();
      let aB = await res.storage.accountBorrows.get(accounts[0]);

      console.log("Account Borrows amount: ", await aB.amount);
      console.log(
        "Account Tokens amount: ",
        await res.storage.accountTokens.get(accounts[0])
      );

      let x = await XTZ.at(fa[fa.length - 2]);
      let xRes = await x.storage();
      let xB = await xRes.ledger.get(accounts[0]);
      console.log("Balance:", await xB.balance);


    });
  });

  describe("safeReddem", async () => {
    it("Safe Reddem 20 for account 0", async () => {
      var amount = 20;
      await cInstance.useController(
        "safeRedeem",
        amount,
        qTokens[qTokens.length - 4]
      );

      let token = await qT.at(qTokens[qTokens.length - 4]);
      let res = await token.storage();
      let aB = await res.storage.accountBorrows.get(accounts[0]);

      console.log("Account Borrows amount: ", await aB.amount);
      console.log(
        "Account Tokens amount: ",
        await res.storage.accountTokens.get(accounts[0])
      );

      let x = await XTZ.at(fa[fa.length - 4]);
      let xRes = await x.storage();
      let xB = await xRes.ledger.get(accounts[0]);
      console.log("Balance:", await xB.balance);
    });
  });

  describe("safeRepay", async () => {
    it("Safe Repay 10 for account 0", async () => {
      var amount = 10;
      await cInstance.useController(
        "safeRepay",
        amount,
        qTokens[qTokens.length - 4]
      );

      let token = await qT.at(qTokens[qTokens.length - 4]);
      let res = await token.storage();
      let aB = await res.storage.accountBorrows.get(accounts[0]);

      console.log("Account Borrows amount: ", await aB.amount);
      console.log(
        "Account Tokens amount: ",
        await res.storage.accountTokens.get(accounts[0])
      );

      let x = await XTZ.at(fa[fa.length - 4]);
      let xRes = await x.storage();
      let xB = await xRes.ledger.get(accounts[0]);
      console.log("Balance:", await xB.balance);
    });
  });

  describe("exitMarket", async () => {
    it("remove accountMembership for account 0", async () => {
      
      const borrowerToken = qTokens[qTokens.length - 5];
      const collateralToken = qTokens[qTokens.length - 6];

      let oracleStorage = await cInstance.storage();
      let value = await oracleStorage.storage.accountMembership.get(accounts[0]);
      console.log("Account Membership 1: ", value);

      await cInstance.useController(
        "exitMarket",
        borrowerToken,
        collateralToken
      );

      oracleStorage = await cInstance.storage();
      value = await oracleStorage.storage.accountMembership.get(accounts[0]);
      console.log("Account Membership 1: ", value);
    });
  });

  // describe("safeLiquidate", async () => {
  //   it("Safe Liquidate", async () => {
  //     var borrower = accounts[0];
  //     var amount = 10;

  //     await cInstance.useController("safeLiquidate", borrower, amount, qTokens[qTokens.length -5]);

  //     let token = await qT.at(qTokens[qTokens.length - 5]);
  //     let res = await token.storage();
  //     let aB = await res.storage.accountBorrows.get(accounts[0]);

  //     console.log("Account Borrows amount: ",await aB.amount);
  //     console.log("Account Tokens amount: ",await res.storage.accountTokens.get(accounts[0]));

  //     let x = await XTZ.at(fa[fa.length - 5]);
  //     let xRes = await x.storage();
  //     let xB = await xRes.ledger.get(accounts[0]);
  //     console.log("Balance:", await xB.balance);

  //   });
  // });

  // describe("exitMarket", async () => {
  //   it("remove to accountMembership", async () => {
  //     const tokens = {
  //       borrowerToken: "KT1Hi94gxTZAZjHaqSFEu3Y8PShsY4gF48Mt",
  //       collateralToken: "KT19DbHikPZEY2H8im1F6HkRh3waWgmbmx67",
  //     };
  //     const borrowerToken = "KT1Hi94gxTZAZjHaqSFEu3Y8PShsY4gF48Mt";
  //     const collateralToken = "KT19DbHikPZEY2H8im1F6HkRh3waWgmbmx67";
  //     await cInstance.useController(
  //       "exitMarket",
  //       borrowerToken,
  //       collateralToken
  //     );
  //   });
  // });
});
