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
        [accounts[2]]: {
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

    const operation2 = await XTZInstance.methods.approve(qTokenAddress, 500).send();
    await operation2.confirmation();

    tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[1])));
    const operation3 = await XTZInstance.methods.approve(qTokenAddress, 500).send();
    await operation3.confirmation();

    tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[2])));
    const operation4 = await XTZInstance.methods.approve(qTokenAddress, 500).send();
    await operation4.confirmation();
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

      // var amount = 250;
      // const operation = await cInstance.methods.useController("safeMint", amount, qTokenAddress).send();
      // await operation.confirmation();
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
      console.log("totalBorrows ", await res.storage.totalBorrows);
      console.log("totalLiquid ", await res.storage.totalLiquid);
      console.log("totalSupply ", await res.storage.totalSupply);
      console.log("borrowIndex ", await res.storage.borrowIndex);
      console.log("totalReserves ", await res.storage.totalReserves);
      let aB = await res.storage.accountBorrows.get(accounts[0]);

      console.log("Account Borrows amount in qT: ", await aB.amount);

      let x = await XTZ.at(fa[fa.length - 2]);
      let xRes = await x.storage();
      let xB = await xRes.ledger.get(accounts[0]);
      console.log("Balance in XTZ Token:", await xB.balance);

      const MStorage = await cInstance.storage();
      console.log("Account MEM: ", await MStorage.storage.accountMembership.get(accounts[0]));
      const arr = [accounts[0], qTokens[qTokens.length - 2]];

      console.log("Acc Borr in Contr: ", (await MStorage.storage.accountBorrows.get(arr)).toString());
    });
  });

  describe("safeRedeem", async () => {
    it("Safe Redeem 20 for account 0", async () => {
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
      console.log("Balance in XTZ:", await xB.balance);
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
      console.log("Balance in XTZ:", await xB.balance);
    });
  });

  describe("exitMarket", async () => {
    it("remove accountMembership for account 0", async () => {
      const borrowerToken = qTokens[qTokens.length - 5];
      const collateralToken = qTokens[qTokens.length - 6];

      let oracleStorage = await cInstance.storage();
      let value = await oracleStorage.storage.accountMembership.get(accounts[0]);
      console.log("Account Membership: ", value);

      const operation = await cInstance.methods.useController(
        "exitMarket",
        borrowerToken,
        collateralToken
      ).send();
      await operation.confirmation();

      oracleStorage = await cInstance.storage();
      value = await oracleStorage.storage.accountMembership.get(accounts[0]);
      console.log("Account Membership after exit: ", value);
    });
  });

  describe("safeMint3", async () => {
    it("Safe Mint 150 for account 2", async () => {
      tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[2])));

      var amount = 500;
      const operation = await cInstance.methods.useController("safeMint", amount, qTokenAddress).send();
      await operation.confirmation();

      let token = await qT.at(qTokenAddress);
      let res = await token.storage();
      console.log(
        "Account Tokens amount acc 2: ",
        await res.storage.accountTokens.get(accounts[2])
      );

      tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])));

      var amount2 = 200;
      const operation2 = await cInstance.methods.useController("safeMint", amount2, qTokenAddress).send();
      await operation2.confirmation();

      let token2 = await qT.at(qTokenAddress);
      let res2 = await token2.storage();
      console.log(
        "Account Tokens amount acc 0: ",
        await res2.storage.accountTokens.get(accounts[0])
      );
    });
  });

  describe("safeBorrow2", async () => {
    it("Safe Borrow 20 for account 2", async () => {
      tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[2])));
      var amount = 20;

      const operation = await cInstance.methods.useController(
        "safeBorrow",
        qTokens[qTokens.length - 2],
        amount,
        qTokens[qTokens.length - 7]
      ).send();
      await operation.confirmation();

      let token = await qT.at(qTokens[qTokens.length - 7]);
      let res = await token.storage();
      console.log("totalBorrows ", await res.storage.totalBorrows);
      console.log("totalLiquid ", await res.storage.totalLiquid);
      console.log("totalSupply ", await res.storage.totalSupply);
      console.log("borrowIndex ", await res.storage.borrowIndex);
      console.log("totalReserves ", await res.storage.totalReserves);

      const value = await res.storage.borrowIndex;
      console.log("BorrowIndex: ", value);

      let aB = await res.storage.accountBorrows.get(accounts[2]);

      console.log("Account Borrows amount: ", await aB.amount);
      console.log("Account Tokens amount: ", await res.storage.accountTokens.get(accounts[2]));

      let x = await XTZ.at(fa[fa.length - 7]);
      let xRes = await x.storage();
      let xB = await xRes.ledger.get(accounts[2]);
      console.log("Balance in XTZ Token:", await xB.balance);

      const MStorage = await cInstance.storage();
      console.log("Account MEM: ", await MStorage.storage.accountMembership.get(accounts[2]));
      const arr = [accounts[2], qTokens[qTokens.length - 7]];

      console.log("Acc Borr: ", (await MStorage.storage.accountBorrows.get(arr)).toString());


      tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])));

      var amount2 = 5;

      const operation2 = await cInstance.methods.useController(
        "safeBorrow",
        qTokens[qTokens.length - 2],
        amount2,
        qTokens[qTokens.length - 7]
      ).send();
      await operation2.confirmation();

      let token2 = await qT.at(qTokens[qTokens.length - 7]);
      let res2 = await token2.storage();
      const value2 = await res2.storage.borrowIndex;
      console.log("BorrowIndex0: ", value2);
      
      let aB2 = await res2.storage.accountBorrows.get(accounts[0]);

      console.log("Account Borrows amount0: ", await aB2.amount);
      console.log("Account Tokens amount: ", await res2.storage.accountTokens.get(accounts[0]));

      let x2 = await XTZ.at(fa[fa.length - 7]);
      let xRes2 = await x2.storage();
      let xB2 = await xRes2.ledger.get(accounts[0]);
      console.log("Balance in XTZ Token0:", await xB2.balance);

      const MStorage2 = await cInstance.storage();
      console.log("Account MEM0: ", await MStorage2.storage.accountMembership.get(accounts[0]));
      const arr2 = [accounts[0], qTokens[qTokens.length - 7]];

      console.log("Acc Borr0: ", (await MStorage2.storage.accountBorrows.get(arr2)).toString());
    });
  });

  describe("safeLiquidate", async () => {
    it("Safe Liquidate", async () => {
      tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])));
      var borrower = accounts[2];
      var amount = 5;

      const MStorage = await cInstance.storage();
      const arr = [accounts[2], qTokens[qTokens.length - 8]];

      console.log("Acc Borr controller: ", (await MStorage.storage.accountBorrows.get(arr)).toString());
      console.log("Acc Tok controller: ", (await MStorage.storage.accountTokens.get(arr)).toString());
      console.log("Account MEM controller: ", await MStorage.storage.accountMembership.get(accounts[2]));


      let token = await qT.at(qTokens[qTokens.length - 8]);
      let res = await token.storage();

      let aB = await res.storage.accountBorrows.get(accounts[2]);
      console.log("ACC Borr TOK 2: ", await aB.amount);

      token = await qT.at(qTokens[qTokens.length - 3]);
      res = await token.storage();
      console.log("Account tokens0: ",await res.storage.accountTokens.get(accounts[0]));

      const operation = await cInstance.methods.useController("safeLiquidate", borrower, amount, qTokens[qTokens.length - 8]).send();
      await operation.confirmation();

      token = await qT.at(qTokens[qTokens.length - 8]);
      res = await token.storage();
      aB = await res.storage.accountBorrows.get(accounts[2]);

      console.log("Account Borrows amount: ", await aB.amount);

      token = await qT.at(qTokens[qTokens.length - 3]);
      res = await token.storage();
      console.log("Account Tokens amount0: ", await res.storage.accountTokens.get(accounts[0]));
    });
  });
});
