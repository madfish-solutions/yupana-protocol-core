const { MichelsonMap } = require("@taquito/michelson-encoder");

const { alice, bob, carol } = require("../scripts/sandbox/accounts");

const { strictEqual } = require("assert");

const { Proxy } = require("../test/utills/Proxy");
const { InterestRate } = require("../test/utills/InterestRate");
const { GetOracle } = require("../test/utills/GetOracle");
const { YToken } = require("../test/utills/YToken");
const { FA12 } = require("../test/utills/FA12");
const { FA2 } = require("../test/utills/FA2");
const { Utils } = require("../test/utills/Utils");

const tokenMetadata = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST").toString("hex"),
  name: Buffer.from("TEST").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata2 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST2").toString("hex"),
  name: Buffer.from("TEST2").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

describe("Proxy tests", async () => {
  let tezos;
  let yToken;
  let interest;
  let interest2;
  let proxy;
  let oracle;
  let fa12;
  let fa12_2;
  let fa2;
  let yTokenContractAddress;
  let interestContractAddress;
  let proxyContractAddress;
  let oracleContractAddress;
  let fa12ContractAddress;
  let fa2ContractAddress;

  before("setup Proxy", async () => {
    tezos = await Utils.initTezos();
    yToken = await YToken.originate(tezos);
    interest = await InterestRate.originate(tezos);
    interest2 = await InterestRate.originate(tezos);
    proxy = await Proxy.originate(tezos);
    fa12 = await FA12.originate(tezos);
    fa12_2 = await FA12.originate(tezos);
    fa2 = await FA2.originate(tezos);
    oracle = await GetOracle.originate(tezos);

    yTokenContractAddress = yToken.contract.address;
    interestContractAddress = interest.contract.address;
    interest2ContractAddress = interest2.contract.address;
    proxyContractAddress = proxy.contract.address;
    oracleContractAddress = oracle.contract.address;
    fa12ContractAddress = fa12.contract.address;
    fa12_2ContractAddress = fa12_2.contract.address;
    fa2ContractAddress = fa2.contract.address;

    await interest.setCoefficients(
      800000000000000000,
      634195839,
      7134703196,
      31709791983
    );
    await interest.updateStorage();

    await interest2.setCoefficients(
      800000000000000000,
      0,
      1585489599,
      34563673262
    );
    await interest2.updateStorage();

    console.log("oracle ", oracleContractAddress);

    // await oracle.updOracle([new Date(), new Date(), 1, 2, 3, 4, 5]);
    // await oracle.updateStorage();

    // await oracle.updReturnAddressOracle(proxyContractAddress);
    // await oracle.updateStorage();
    // strictEqual(oracle.storage.returnAddress, proxyContractAddress);

    await proxy.updateOracle(oracleContractAddress);
    await proxy.updateStorage();
    strictEqual(proxy.storage.oracle, oracleContractAddress);

    await proxy.updateYToken(yTokenContractAddress);
    await proxy.updateStorage();
    strictEqual(proxy.storage.yToken, yTokenContractAddress);

    await interest.updateYToken(yTokenContractAddress);
    await interest.updateStorage();
    strictEqual(interest.storage.yToken, yTokenContractAddress);

    await yToken.setGlobalFactors(
      "500000000000000000",
      "1050000000000000000",
      proxyContractAddress,
      "12"
    );
    await yToken.updateStorage();
    strictEqual(yToken.storage.storage.priceFeedProxy, proxyContractAddress);
  });

  it("set proxy admin by admin", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await proxy.updateAdmin(bob.pkh);
    await proxy.updateStorage();
    strictEqual(proxy.storage.admin, bob.pkh);
  });

  it("set yToken admin by not admin", async () => {
    try {
      tezos = await Utils.setProvider(tezos, bob.sk);
      await yToken.setAdmin(carol.pkh);
      await yToken.updateStorage();
      console.log("no error found!");
    } catch (e) {
      console.log("not-admin");
    }
  });

  it("set yToken admin by admin", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await yToken.setAdmin(bob.pkh);
    await yToken.updateStorage();
    strictEqual(yToken.storage.storage.admin, bob.pkh);
  });

  it("add market [0] by non admin", async () => {
    try {
      tezos = await Utils.setProvider(tezos, alice.sk);
      await yToken.addMarket(
        interestContractAddress,
        fa12ContractAddress,
        500000000000000000,
        500000000000000000,
        5000000000000,
        tokenMetadata,
        "fA2"
      );
      await yToken.updateStorage();
      var r = await yToken.storage.storage.tokenInfo.get(0);
      strictEqual(r.mainToken, fa12ContractAddress);

      await proxy.updatePair(0n, "BTC-USDT");
      await proxy.updateStorage();
      strictEqual(await proxy.storage.pairName.get(0), "BTC-USDT");

      let pairId = await proxy.storage.pairId.get("BTC-USDT");
      strictEqual(pairId.toString(), "0");
      console.log("no error found!");
    } catch (e) {
      console.log("not-admin");
    }
  });

  it("add market [0] by admin", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest2ContractAddress,
      fa12ContractAddress,
      650000000000000000,
      200000000000000000,
      5000000000000,
      tokenMetadata,
      "fA12",
      0
    );
    await yToken.updateStorage();
    var r = await yToken.storage.storage.tokenInfo.get(0);
    strictEqual(r.mainToken, fa12ContractAddress);

    await proxy.updatePair(0n, "BTC-USDT");
    await proxy.updateStorage();
    strictEqual(await proxy.storage.pairName.get(0), "BTC-USDT");

    let pairId = await proxy.storage.pairId.get("BTC-USDT");
    strictEqual(pairId.toString(), "0");
  });

  // it("update metadata [0] by non admin", async () => {
  //   try {
  //     tezos = await Utils.setProvider(tezos, alice.sk);
  //     await yToken.updMetadata(
  //       0,
  //       tokenMetadata2
  //     );
  //     await yToken.updateStorage();
  //     console.log("no error found!");
  //   }
  //   catch(e) {
  //     console.log('permition');
  //   }
  // });

  // it("update metadata [0] by admin", async () => {
  //   tezos = await Utils.setProvider(tezos, bob.sk);
  //   await yToken.updMetadata(
  //     0,
  //     tokenMetadata2
  //   );
  //   await yToken.updateStorage();
  //   console.log(await yToken.storage.storage.tokenMetadata.get(0));
  // });

  it("add market [1]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interestContractAddress,
      fa12_2ContractAddress,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata,
      "fA12"
    );
    await yToken.updateStorage();
    var r = await yToken.storage.storage.tokenInfo.get(1);
    strictEqual(r.mainToken, fa12_2ContractAddress);

    await proxy.updatePair(1, "ETH-USDT");
    await proxy.updateStorage();
    strictEqual(await proxy.storage.pairName.get(1), "ETH-USDT");

    let pairId = await proxy.storage.pairId.get("ETH-USDT");
    strictEqual(pairId.toString(), "1");
  });

  it("mint fa2 tokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await fa12.mint(10000000000000000000);
    await fa12.updateStorage();

    res = await fa12.storage.ledger.get(bob.pkh);

    strictEqual(await res.balance.toString(), "10000000000000000000");
  });

  it("mint 2", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await fa12_2.mint(10000000000000000000);
    await fa12_2.updateStorage();

    res = await fa12_2.storage.ledger.get(alice.pkh);

    strictEqual(await res.balance.toString(), "10000000000000000000");
  });

  it("mint non-existent yToken by alice", async () => {
    try {
      await yToken.mint(32, 1000000);
      await yToken.updateStorage();
      console.log("no error found!");
    } catch (e) {
      console.log("non-existent token");
    }
  });

  it("mint yTokens by alice", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await fa12_2.approve(yTokenContractAddress, 100000000000);
    await fa12_2.updateStorage();

    await yToken.mint(1, 10000000000);
    await yToken.updateStorage();

    let res = await fa12_2.storage.ledger.get(alice.pkh);
    strictEqual(await res.balance.toString(), "9999999990000000000");

    let yTokenRes = await yToken.storage.storage.accountInfo.get(alice.pkh);
    let yTokenBalance = await yTokenRes.balances.get("1");

    strictEqual(
      await yTokenBalance.balance.toPrecision(40).split(".")[0],
      "10000000000000000000000000000"
    );
  });

  it("mint yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await fa12.approve(yTokenContractAddress, 100000000000);
    await fa12.updateStorage();

    await yToken.mint(0, 100000);
    await yToken.updateStorage();

    let res = await fa12.storage.ledger.get(bob.pkh);
    strictEqual(await res.balance.toString(), "9999999999999900000");

    let yTokenRes = await yToken.storage.storage.accountInfo.get(bob.pkh);
    let yTokenBalance = await yTokenRes.balances.get("0");
    strictEqual(
      await yTokenBalance.balance.toPrecision(40).split(".")[0],
      "100000000000000000000000"
    );
  });

  it("enterMarket non-existent yToken by bob", async () => {
    try {
      tezos = await Utils.setProvider(tezos, bob.sk);
      await yToken.enterMarket(3);
      await yToken.updateStorage();
      console.log("no error found!");
    } catch (e) {
      console.log("non-existent yToken");
    }
  });

  it("enterMarket [0] by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await yToken.enterMarket(0);
    await yToken.updateStorage();
    res = await yToken.storage.storage.accountInfo.get(bob.pkh);
    strictEqual(res.markets.toString(), "0");
  });

  it("enterMarket [1] by alice", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);

    await yToken.enterMarket(1);
    await yToken.updateStorage();
    res = await yToken.storage.storage.accountInfo.get(alice.pkh);
    strictEqual(res.markets.toString(), "1");
  });

  it("borrow yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.updateAndBorrow(proxy, 1, 50000);
    await yToken.updateStorage();

    res = await yToken.storage.storage.accountInfo.get(bob.pkh);
    let balances = await res.balances.get("1");

    strictEqual(
      await balances.borrow.toPrecision(40).split(".")[0],
      "50000000000000000000000"
    );
  });

  it("borrow yTokens by bob (2)", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await Utils.bakeBlocks(tezos, 7);

    await yToken.updateAndBorrow(proxy, 1, 1000);
    await yToken.updateStorage();

    let res = await yToken.storage.storage.accountInfo.get(bob.pkh);
    let balances = await res.balances.get("1");

    console.log(balances.borrow.toPrecision(40).split(".")[0]);
  });

  it("borrow more than allowed yTokens by bob", async () => {
    try {
      tezos = await Utils.setProvider(tezos, bob.sk);
      await yToken.updateAndBorrow(proxy, 1, 200000);
      await yToken.updateStorage();
      console.log("no error found!");
    } catch (e) {
      console.log("yToken/exceeds-the-permissible-debt");
    }
  });

  it("borrow more than exists yTokens by alice", async () => {
    try {
      tezos = await Utils.setProvider(tezos, alice.sk);

      await yToken.updateAndBorrow2(proxy, 0, 200000);
      await yToken.updateStorage();
      console.log("no error found!");
    } catch (e) {
      console.log("yToken/amount-too-big");
    }
  });

  it("repay yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await fa12_2.approve(yTokenContractAddress, 100000);
    await fa12_2.updateStorage();

    await yToken.updateAndRepay(proxy, 1, 40000);
    await yToken.updateStorage();

    let yTokenRes = await yToken.storage.storage.accountInfo.get(bob.pkh);
    let yTokenBorrow = await yTokenRes.balances.get("1");
    console.log(yTokenBorrow.borrow.toPrecision(40).split(".")[0]);
  });

  it("redeem yTokens by bob", async () => {
    try {
      tezos = await Utils.setProvider(tezos, bob.sk);

      await yToken.updateAndRedeem(proxy, 0, 1);
      await yToken.updateStorage();
      console.log("no error found!");
    } catch (e) {
      console.log("yToken/token-taken-as-collateral");
    }
  });

  it("try exit market yTokens by bob", async () => {
    try {
      tezos = await Utils.setProvider(tezos, bob.sk);

      await yToken.exitMarket(0);
      await yToken.updateStorage();
      console.log("no error found!");
    } catch (e) {
      console.log("debt-not-repaid");
    }
  });

  it("repay 5 yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await fa12_2.mint(10000);
    await fa12_2.updateStorage();

    let res = await fa12_2.storage.ledger.get(bob.pkh);
    console.log(await res.balance.toString());

    let yTokenRes = await yToken.storage.storage.accountInfo.get(bob.pkh);
    let yTokenBalance = await yTokenRes.balances.get("1");
    console.log(yTokenBalance.balance.toPrecision(40).split(".")[0]);

    await yToken.updateAndRepay(proxy, 1, 0);
    await yToken.updateStorage();

    yTokenRes = await yToken.storage.storage.accountInfo.get(bob.pkh);
    yTokenBalance = await yTokenRes.balances.get("1");
    strictEqual(await yTokenBalance.borrow.toString(), "0");
  });

  it("exit market yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    let res = await yToken.storage.storage.accountInfo.get(bob.pkh);
    strictEqual(await res.markets.toString(), "0");

    await yToken.updateAndExit(proxy, 0);
    await yToken.updateStorage();

    res = await yToken.storage.storage.accountInfo.get(bob.pkh);
    strictEqual(await res.markets.toString(), "");
  });
});
