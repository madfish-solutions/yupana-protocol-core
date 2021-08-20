const { MichelsonMap } = require("@taquito/michelson-encoder");

const { alice, bob, carol } = require("../scripts/sandbox/accounts");

const { strictEqual } = require("assert");

const { Proxy } = require("../test/utills/Proxy");
const { GetOracle } = require("../test/utills/GetOracle");
const { YToken } = require("../test/utills/YToken");
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
  let proxy;
  let oracle;
  let yToken;
  let proxyContractAddress;

  before("setup Proxy", async () => {
    tezos = await Utils.initTezos();
    proxy = await Proxy.originate(tezos);
    oracle = await GetOracle.originate(tezos);
    yToken = await YToken.originate(tezos);

    proxyContractAddress = proxy.contract.address;
    oracleContractAddress = oracle.contract.address;
    yTokenContractAddress = yToken.contract.address;

    tezos = await Utils.setProvider(tezos, alice.sk);

    let operation = await tezos.contract.transfer({
      to: carol.pkh,
      amount: 50000000,
      mutez: true,
    });
    await confirmOperation(tezos, operation.hash);

    await oracle.updReturnAddressOracle(proxyContractAddress);
    await oracle.updateStorage();
    strictEqual(oracle.storage.returnAddress, proxyContractAddress);

    await proxy.updateOracle(oracleContractAddress);
    await proxy.updateStorage();
    strictEqual(proxy.storage.storage.oracle, oracleContractAddress);

    await proxy.updateYToken(yTokenContractAddress);
    await proxy.updateStorage();
    strictEqual(proxy.storage.storage.yToken, yTokenContractAddress);

    await yToken.setGlobalFactors("110", "120", proxyContractAddress);
    await yToken.updateStorage();
    strictEqual(yToken.storage.storage.priceFeedProxy, proxyContractAddress);
  });

  it("set Proxy admin", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await proxy.updateAdmin(bob.pkh);
    await proxy.updateStorage();
    strictEqual(proxy.storage.storage.admin, bob.pkh);
  });

  it("update Pair by not admin", async () => {
    try {
      tezos = await Utils.setProvider(tezos, alice.sk);
      await proxy.updatePair(0n, "BTC-USDT");
      await proxy.updateStorage();
    } catch (e) {
      console.log("not-admin");
    }
  });

  it("update Pair by admin", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await proxy.updatePair(0n, "BTC-USDT");
    await proxy.updateStorage();
    strictEqual(await proxy.storage.storage.pairName.get(0), "BTC-USDT");
    let pairId = await proxy.storage.storage.pairId.get("BTC-USDT");
    strictEqual(pairId.toString(), "0");
  });

  it("getting a price not for an permitted address", async () => {
    try {
      tezos = await Utils.setProvider(tezos, bob.sk);
      await proxy.getPrice(0n);
      await proxy.updateStorage();
    } catch (e) {
      console.log("not-yToken");
    }
  });

  it("add market", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await yToken.addMarket(
      alice.pkh,
      alice.pkh,
      0,
      0,
      10000,
      tokenMetadata,
      "fA2",
      0
    );
    await yToken.updateStorage();
    var r = await yToken.storage.storage.tokenInfo.get(0);
    strictEqual(r.mainToken, alice.pkh);
  });

  it("getting a price for an permitted address", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    var r = await yToken.storage.storage.tokenInfo.get(0);
    strictEqual(r.lastPrice.toString(), "0");

    await yToken.updatePrice([0n]);
    await yToken.updateStorage();

    r = await yToken.storage.storage.tokenInfo.get(0);
    strictEqual(r.lastPrice.toString(), "100");
  });
});
