const { MichelsonMap } = require("@taquito/michelson-encoder");

const { alice, bob, carol } = require("../scripts/sandbox/accounts");

const { strictEqual } = require("assert");

const { Proxy } = require("../test/utills/Proxy");
const { InterestRate } = require("../test/utills/InterestRate");
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
  let yToken;
  let interest;
  let proxy;
  let oracle;
  let yTokenContractAddress;
  let interestContractAddress;
  let proxyContractAddress;
  let oracleContractAddress;

  before("setup Proxy", async () => {
    tezos = await Utils.initTezos();
    yToken = await YToken.originate(tezos);
    interest = await InterestRate.originate(tezos);
    proxy = await Proxy.originate(tezos);
    oracle = await GetOracle.originate(tezos);

    yTokenContractAddress = yToken.contract.address;
    interestContractAddress = interest.contract.address;
    proxyContractAddress = proxy.contract.address;
    oracleContractAddress = oracle.contract.address;

    await oracle.updReturnAddressOracle(proxyContractAddress);
    await oracle.updateStorage();
    strictEqual(oracle.storage.returnAddress, proxyContractAddress);

    await proxy.updateOracle(oracleContractAddress);
    await proxy.updateStorage();
    strictEqual(proxy.storage.storage.oracle, oracleContractAddress);

    await proxy.updateYToken(yTokenContractAddress);
    await proxy.updateStorage();
    strictEqual(proxy.storage.storage.yToken, yTokenContractAddress);

    await interest.updateRateYToken(yTokenContractAddress);
    await interest.updateStorage();
    strictEqual(interest.storage.storage.yToken, yTokenContractAddress);

    await yToken.setGlobalFactors("110", "120", proxyContractAddress);
    await yToken.updateStorage();
    strictEqual(yToken.storage.storage.priceFeedProxy, proxyContractAddress);
  });

  it("set yToken admin by not admin", async () => {
    try {
      tezos = await Utils.setProvider(tezos, bob.sk);
      await yToken.setAdmin(carol.pkh);
      await proxy.updateStorage();
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
});
