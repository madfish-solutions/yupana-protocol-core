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
    tezos = new TezosToolkit(tezos.rpc.url);
    tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])));

    cInstance = await tezos.contract.at((await Controller.deployed()).address);
    fInstance = await tezos.contract.at((await Factory.deployed()).address);

    const operation = await cInstance.methods.setFactory(fInstance.address).send();
    await operation.confirmation();
    const cStorage = await cInstance.storage();
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
    XTZInstance = await tezos.contract.at((await XTZ.new(XTZStorage)).address);

    fa.push(XTZInstance.address);
    console.log("Created FA1.2 token:", XTZInstance.address);

    const operation = await fInstance.methods.launchToken(XTZInstance.address).send();
    await operation.confirmation();
    const fStorage = await fInstance.storage();
    qTokenAddress = await fStorage.tokenList.get(XTZInstance.address);
    qTokens.push(qTokenAddress);
    console.log("New qToken:", qTokenAddress);

    const operation2 = await XTZInstance.methods.approve(qTokenAddress, 2000).send();
    await operation2.confirmation();

    tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[1])));
    const operation3 = await XTZInstance.methods.approve(qTokenAddress, 2000).send();
    await operation3.confirmation();
    tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])));
  });

  describe("setOracle", async () => {
    it("set new oracle", async () => {
      const oracle = "KT1Hi94gxTZAZjHaqSFEu3Y8PShsY4gF48Mt";
      const operation = await cInstance.methods.useController("setOracle", oracle, qTokenAddress).send();
      await operation.confirmation();
      const oracleStorage = await cInstance.storage();
      const value = await oracleStorage.storage.markets.get(qTokenAddress);
      console.log("NewOracle:", await value.oracle);
    });
  });

  describe("safeMint", async () => {
    it("Safe Mint 140 for account 0", async () => {
      var amount = 140;
      const operation = await cInstance.methods.useController("safeMint", amount, qTokenAddress).send();
      await operation.confirmation();

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
      tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[1])));

      var amount = 150;
      const operation = await cInstance.methods.useController("safeMint", amount, qTokenAddress).send();
      await operation.confirmation();

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
      tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])));
    });
  });

  describe("safeBorrow", async () => {
    it("Safe Borrow 10 for account 0", async () => {
      var amount = 10;

      const operation = await cInstance.methods.useController(
        "safeBorrow",
        qTokens[qTokens.length - 3],
        amount,
        qTokens[qTokens.length - 2]
      ).send();
      await operation.confirmation();

      let token = await qT.at(qTokens[qTokens.length - 2]);
      let res = await token.storage();
      let aB = await res.storage.accountBorrows.get(accounts[0]);

      console.log("Account Borrows amount: ", await aB.amount);

      let x = await XTZ.at(fa[fa.length - 2]);
      let xRes = await x.storage();
      let xB = await xRes.ledger.get(accounts[0]);
      console.log("Balance in XTZ Token:", await xB.balance);

      const MStorage = await cInstance.storage();
      console.log("Account MEM: ", await MStorage.storage.accountMembership.get(accounts[0]));
      const arr = [accounts[0], qTokens[qTokens.length - 2]];

      console.log("Acc Borr: ", (await MStorage.storage.accountBorrows.get(arr)).toString());
    });
  });

  describe("safeReddem", async () => {
    it("Safe Reddem 20 for account 0", async () => {
      var amount = 20;
      const operation = await cInstance.methods.useController(
        "safeRedeem",
        amount,
        qTokens[qTokens.length - 4]
      ).send();
      await operation.confirmation();

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
      const operation = await cInstance.methods.useController(
        "safeRepay",
        amount,
        qTokens[qTokens.length - 4]
      ).send();
      await operation.confirmation();

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

      // let value2 = await oracleStorage.storage.accountBorrows.get(accounts[1]);
      // console.log("Account Borrows 1: ", value2);

      const operation = await cInstance.methods.useController(
        "exitMarket",
        borrowerToken,
        collateralToken
      ).send();
      await operation.confirmation();

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
