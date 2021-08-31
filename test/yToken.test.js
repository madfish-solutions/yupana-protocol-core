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

const { confirmOperation } = require("../scripts/confirmation");

const tokenMetadata = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST").toString("hex"),
  name: Buffer.from("TEST").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

describe("Proxy tests", async () => {
  let tezos;
  let yToken;
  let interest;
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
    proxy = await Proxy.originate(tezos);
    fa12 = await FA12.originate(tezos);
    fa12_2 = await FA12.originate(tezos);
    fa2 = await FA2.originate(tezos);
    oracle = await GetOracle.originate(tezos);

    yTokenContractAddress = yToken.contract.address;
    interestContractAddress = interest.contract.address;
    proxyContractAddress = proxy.contract.address;
    oracleContractAddress = oracle.contract.address;
    fa12ContractAddress = fa12.contract.address;
    fa12_2ContractAddress = fa12_2.contract.address;
    fa2ContractAddress = fa2.contract.address;

    await oracle.updReturnAddressOracle(proxyContractAddress);
    await oracle.updateStorage();
    strictEqual(oracle.storage.returnAddress, proxyContractAddress);

    await proxy.updateOracle(oracleContractAddress);
    await proxy.updateStorage();
    strictEqual(proxy.storage.oracle, oracleContractAddress);

    await proxy.updateYToken(yTokenContractAddress);
    await proxy.updateStorage();
    strictEqual(proxy.storage.yToken, yTokenContractAddress);

    await interest.updateRateYToken(yTokenContractAddress);
    await interest.updateStorage();
    strictEqual(interest.storage.yToken, yTokenContractAddress);

    await yToken.setGlobalFactors("110", "120", proxyContractAddress, "10");
    await yToken.updateStorage();
    strictEqual(yToken.storage.storage.priceFeedProxy, proxyContractAddress);
  });

  it("set yToken admin by not admin", async () => {
    try {
      tezos = await Utils.setProvider(tezos, bob.sk);
      await yToken.setAdmin(carol.pkh);
      await yToken.updateStorage();
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

  it("add market [0]", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await yToken.addMarket(
      interestContractAddress,
      fa12ContractAddress,
      100,
      150,
      100,
      tokenMetadata,
      "fA12"
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

  it("add market [1]", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await yToken.addMarket(
      interestContractAddress,
      fa12_2ContractAddress,
      100,
      150,
      100,
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

  it("mint fa12 tokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await fa12.mint(100000000000);
    await fa12.updateStorage();

    let res = await fa12.storage.ledger.get(bob.pkh);

    strictEqual(await res.balance.toString(), "100000000000");

    tezos = await Utils.setProvider(tezos, alice.sk);
    await fa12_2.mint(100000000000);
    await fa12_2.updateStorage();

    res = await fa12_2.storage.ledger.get(alice.pkh);

    strictEqual(await res.balance.toString(), "100000000000");
  });

  it("mint yTokens by alice", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await fa12_2.approve(yTokenContractAddress, 100000000000);
    await fa12_2.updateStorage();

    await yToken.mint(1, 1000000);
    await yToken.updateStorage();

    let res = await fa12_2.storage.ledger.get(alice.pkh);
    strictEqual(await res.balance.toString(), "99999000000");

    let yTokenRes = await yToken.storage.storage.accountInfo.get(alice.pkh);
    let yTokenBalance = await yTokenRes.balances.get("1");

    strictEqual(await yTokenBalance.toPrecision(40).split('.')[0], "1000000000000000000000000");
  });

  it("mint yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await fa12.approve(yTokenContractAddress, 100000000000);
    await fa12.updateStorage();

    await yToken.mint(0, 1000000);
    await yToken.updateStorage();

    let res = await fa12.storage.ledger.get(bob.pkh);
    strictEqual(await res.balance.toString(), "99999000000");

    let yTokenRes = await yToken.storage.storage.accountInfo.get(bob.pkh);
    let yTokenBalance = await yTokenRes.balances.get("0");
    strictEqual(await yTokenBalance.toPrecision(40).split('.')[0], "1000000000000000000000000");
  });

  it("enterMarket and borrow yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await yToken.enterMarket(0);
    await yToken.updateStorage();

    await yToken.updateInterest(0);
    await yToken.updateStorage();

    await yToken.updateInterest(1);
    await yToken.updateStorage();

    await yToken.updatePrice([0, 1]);
    await yToken.updateStorage();

    await yToken.borrow(1, 100000);
    await yToken.updateStorage();

    res = await yToken.storage.storage.accountInfo.get(bob.pkh);
    let balance = await res.borrows.get("1");

    strictEqual(await balance.toPrecision(40).split('.')[0], "100000000000000000000000");
  });

  it("repay yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await fa12_2.approve(yTokenContractAddress, 100000);
    await fa12_2.updateStorage();

    await yToken.repay(1, 50000);
    await yToken.updateStorage();

    let yTokenRes = await yToken.storage.storage.accountInfo.get(bob.pkh);
    let yTokenBalance = await yTokenRes.borrows.get("1");
    strictEqual(await yTokenBalance.toPrecision(40).split('.')[0], "50000000000000000000000");
  });

  it("redeem yTokens by alice", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);

    let res = await fa12_2.storage.ledger.get(alice.pkh);
    strictEqual(await res.balance.toString(), "99999000000");

    await yToken.redeem(1, 100000);
    await yToken.updateStorage();

    res = await fa12_2.storage.ledger.get(alice.pkh);
    strictEqual(await res.balance.toString(), "99999100000");

    let yTokenRes = await yToken.storage.storage.accountInfo.get(alice.pkh);
    let yTokenBalance = await yTokenRes.balances.get("1");
    strictEqual(await yTokenBalance.toPrecision(40).split('.')[0], "894736842105263157894737");
  });

  it("try exit market yTokens by bob", async () => {
    try {
      tezos = await Utils.setProvider(tezos, bob.sk);

      await yToken.exitMarket(0);
      await yToken.updateStorage();
    } catch (e) {
      console.log("debt-not-repaid");
    }
  });

  it("repay 5 yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    let yTokenRes = await yToken.storage.storage.accountInfo.get(bob.pkh);
    let yTokenBalance = await yTokenRes.borrows.get("1");
    console.log(yTokenBalance)

    await yToken.repay(1, 40000);
    await yToken.updateStorage();

    yTokenRes = await yToken.storage.storage.accountInfo.get(bob.pkh);
    yTokenBalance = await yTokenRes.borrows.get("1");
    strictEqual(await yTokenBalance.toPrecision(40).split('.')[0], "10000000000000000000000");

    await yToken.repay(1, 0);
    await yToken.updateStorage();

    yTokenRes = await yToken.storage.storage.accountInfo.get(bob.pkh);
    yTokenBalance = await yTokenRes.borrows.get("1");
    strictEqual(await yTokenBalance.toPrecision(40).split('.')[0], "0");
  });

  it("exit market yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await yToken.exitMarket(0);
    await yToken.updateStorage();
  });
});
