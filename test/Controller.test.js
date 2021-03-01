const { MichelsonMap } = require("@taquito/michelson-encoder");
const { InMemorySigner } = require("@taquito/signer");

const { accounts } = require("../scripts/sandbox/accounts");
const { accountsMap } = require("../scripts/sandbox/accounts");

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
  before("setup", async () => {
    cInstance = await Controller.deployed();
    fInstance = await Factory.deployed();

    tezos.setProvider({
      signer: await InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])),
    });

    await cInstance.setFactory(fInstance.address);
    const cStorage = await cInstance.storage();
    const value = cStorage.storage.factory;
    console.log("NewFactory: ", value);
  });

  beforeEach("setup", async () => {

    // const DEFAULT = accounts[0];
    // const SENDER = accounts[1];

    // const defaultsBalance = 1500;
    // const defaultsAmt = 15;

    // const totalSupply = 50000;
    // const decimal = 1e+6;

    // let XTZ_Instance;
    // let storage;

    // storage = {
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

    // XTZInstance = await XTZ.new(storage);

    let XTZStorage = {
      totalSupply: 0,
      ledger: MichelsonMap.fromLiteral({
        [accounts[0]]: {
          balance: 15000,
          allowances: MichelsonMap.fromLiteral({}),
        },
      }),
    };
    XTZInstance = await XTZ.new(XTZStorage);
    
    fa.push(XTZInstance.address);
    console.log("Created FA1.2 token:", XTZInstance.address);

    await fInstance.launchToken(XTZInstance.address);

    const fStorage = await fInstance.storage();
    qTokenAddress = await fStorage.tokenList.get(XTZInstance.address);
    qTokens.push(qTokenAddress);
    console.log("New qToken:", qTokenAddress);
    await XTZInstance.approve(qTokenAddress, 2000);
  });

  describe("setOracle", async () => {
    it("set new oracle", async () => {
      const oracle = "KT1Hi94gxTZAZjHaqSFEu3Y8PShsY4gF48Mt";
      await cInstance.useController("setOracle", oracle, qTokenAddress);
      const oracleStorage = await cInstance.storage();
      const value = await oracleStorage.storage.markets.get(qTokenAddress);
      console.log("NewOracle:", value);
    });
  });

  describe("safeMint", async () => {
    it("Safe Mint for qToken", async () => {
      tezos.setProvider({
        signer: await InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])),
      });

      console.log(qTokens);

      var amount = 142;
      await cInstance.useController("safeMint", amount, qTokenAddress);

      let token = await qT.at(qTokenAddress);
      let res = await token.storage();
      console.log(res);
      console.log(await res.storage.accountTokens.get(accounts[0]));
    });
  });
  
  describe("safeBorrow", async () => {
    it("Safe Borrow", async () => {
      tezos.setProvider({
        signer: await InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])),
      });

      console.log(qTokens);

      var amount = 10;
      await cInstance.useController("safeBorrow", qTokens[qTokens.length -2], amount, qTokens[qTokens.length - 1]);

      const cStorage = await cInstance.storage();
      console.log(await cStorage.storage.accountMembership.get(accounts[0]));


      let token = await qT.at(qTokens[qTokens.length -2]);
      let res = await token.storage();
      console.log(res);
      console.log(await res.storage.accountBorrows.get(accounts[0]));
    });
  });

  describe("safeReddem", async () => {
    it("Safe Reddem", async () => {
      var amount = 10;
      await cInstance.useController("safeRedeem", amount, qTokens[qTokens.length - 3]);

      let token = await qT.at(qTokens[qTokens.length - 3]);
      let res = await token.storage();
      console.log(res);
      console.log(await res.storage.accountBorrows.get(accounts[0]));
      console.log(await res.storage.accountTokens.get(accounts[0]));

    });
  });

  describe("safeRepay", async () => {
    it("Safe Repay", async () => {
      var amount = 10;
      await cInstance.useController("safeRepay", amount, qTokens[qTokens.length - 4]);

      let token = await qT.at(qTokens[qTokens.length - 4]);
      let res = await token.storage();
      console.log(res);
      console.log(await res.storage.accountBorrows.get(accounts[0]).amount);
      console.log(await res.storage.accountTokens.get(accounts[0]));
    });
  });

  // describe("safeLiquidate", async () => {
  //   it("Safe Liquidate", async () => {
  //     var borrower = "tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg";
  //     var amount = 20;

  //     const cStorage = await cInstance.storage();
  //     const value = await cStorage.storage.accountBorrows;
      
  //     console.log(value);
  //     await cInstance.useController("safeLiquidate", borrower, amount, qTokens[qTokens.length -5]);
  //   });
  // });

  // describe("register", async () => {
  //   it("register new contracts", async () => {
  //     const token = "KT1Hi94gxTZAZjHaqSFEu3Y8PShsY4gF48Mt";
  //     const qToken = "KT19DbHikPZEY2H8im1F6HkRh3waWgmbmx67";
  //     await cInstance.useController("register", qToken, token);

  //     const cStorage = await cInstance.storage();
  //     const value = cStorage.storage.qTokens;
  //     console.log(value);
  //     assert.notStrictEqual(value, undefined);
  //   });
  // });

  // describe("updatePrice", async () => {
  //   it("upd price", async () => {
  //     const qToken = "KT19DbHikPZEY2H8im1F6HkRh3waWgmbmx67";
  //     const price = 100;
  //     await cInstance.useController("updatePrice", price, qToken);
  //   });
  // });

  // describe("updateQToken", async () => {
  //   it("upd params for qToken", async () => {
  //     const user = "tz1WBSTvfSC58wjHGsPeYkcftmbgscUybNuk";
  //     const balance = 120;
  //     const borrow = 50;
  //     const exchangeRate = 10;
  //     await cInstance.useController(
  //       "updateQToken",
  //       user,
  //       balance,
  //       borrow,
  //       exchangeRate
  //     );
  //   });
  // });

  // describe("enterMarket", async () => {
  //   it("add to accountMembership", async () => {
  //     const tokens = {
  //       borrowerToken: "KT1Hi94gxTZAZjHaqSFEu3Y8PShsY4gF48Mt",
  //       collateralToken: "KT19DbHikPZEY2H8im1F6HkRh3waWgmbmx67",
  //     };
  //     const borrowerToken = "KT1Hi94gxTZAZjHaqSFEu3Y8PShsY4gF48Mt";
  //     const collateralToken = "KT19DbHikPZEY2H8im1F6HkRh3waWgmbmx67";

  //     await cInstance.useController(
  //       "enterMarket",
  //       borrowerToken,
  //       collateralToken
  //     );
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

  // describe("safeMint", async () => {
  //   it("safe Mint", async () => {
  //     const token = "KT19DbHikPZEY2H8im1F6HkRh3waWgmbmx67";
  //     const amt = 10;
  //     await cInstance.useController("safeMint", amt, token);
  //   });
  // });
});
