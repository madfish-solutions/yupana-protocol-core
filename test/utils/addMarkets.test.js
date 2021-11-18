const { MichelsonMap } = require("@taquito/michelson-encoder");

const {
  alice,
  bob,
  carol,
  peter,
  dev,
  dev2,
} = require("../scripts/sandbox/accounts");

const { strictEqual, rejects, ok } = require("assert");

const { Proxy } = require("../test/utils/proxy");
const { InterestRate } = require("../test/utils/interestRate");
const { GetOracle } = require("../test/utils/getOracle");
const { YToken } = require("../test/utils/yToken");
const { FA12 } = require("../test/utils/fa12");
const { FA2 } = require("../test/utils/fa2");
const { Utils } = require("../test/utils/utils");

const tokenMetadata0 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST0").toString("hex"),
  name: Buffer.from("TEST0").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata1 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST1").toString("hex"),
  name: Buffer.from("TEST1").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata2 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST2").toString("hex"),
  name: Buffer.from("TEST2").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata3 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST3").toString("hex"),
  name: Buffer.from("TEST3").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata4 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST4").toString("hex"),
  name: Buffer.from("TEST4").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata5 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST5").toString("hex"),
  name: Buffer.from("TEST5").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata6 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST6").toString("hex"),
  name: Buffer.from("TEST6").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata7 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST7").toString("hex"),
  name: Buffer.from("TEST7").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata8 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST8").toString("hex"),
  name: Buffer.from("TEST8").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata9 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST9").toString("hex"),
  name: Buffer.from("TEST9").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata10 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST10").toString("hex"),
  name: Buffer.from("TEST10").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata11 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST11").toString("hex"),
  name: Buffer.from("TEST11").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata12 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST12").toString("hex"),
  name: Buffer.from("TEST12").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata13 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST13").toString("hex"),
  name: Buffer.from("TEST13").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata14 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST14").toString("hex"),
  name: Buffer.from("TEST14").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata15 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST15").toString("hex"),
  name: Buffer.from("TEST15").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata16 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST16").toString("hex"),
  name: Buffer.from("TEST16").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata17 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST17").toString("hex"),
  name: Buffer.from("TEST17").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata18 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST18").toString("hex"),
  name: Buffer.from("TEST18").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata19 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST19").toString("hex"),
  name: Buffer.from("TEST19").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata20 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST20").toString("hex"),
  name: Buffer.from("TEST20").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

const tokenMetadata21 = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TST21").toString("hex"),
  name: Buffer.from("TEST21").toString("hex"),
  decimals: Buffer.from("6").toString("hex"),
  icon: Buffer.from("").toString("hex"),
});

describe("AddMarkets tests", async () => {
  let tezos;
  let yToken;
  let proxy;
  let oracle;

  let interest0;
  let interest1;
  let interest2;
  let interest3;
  let interest4;
  let interest5;
  let interest6;
  let interest7;
  let interest8;
  let interest9;
  let interest10;
  let interest11;
  let interest12;
  let interest13;
  let interest14;
  let interest15;
  let interest16;
  let interest17;
  let interest18;
  let interest19;
  let interest20;
  let interest21;

  let fa12_0;
  let fa12_1;
  let fa12_2;
  let fa12_3;
  let fa12_4;
  let fa12_5;
  let fa12_6;
  let fa12_7;
  let fa12_8;
  let fa12_9;
  let fa12_10;
  let fa12_11;
  let fa12_12;
  let fa12_13;
  let fa12_14;
  let fa12_15;
  let fa12_16;
  let fa12_17;
  let fa12_18;
  let fa12_19;
  let fa12_20;
  let fa12_21;

  let fa12_0ContractAddress;
  let fa12_1ContractAddress;
  let fa12_2ContractAddress;
  let fa12_3ContractAddress;
  let fa12_4ContractAddress;
  let fa12_5ContractAddress;
  let fa12_6ContractAddress;
  let fa12_7ContractAddress;
  let fa12_8ContractAddress;
  let fa12_9ContractAddress;
  let fa12_10ContractAddress;
  let fa12_11ContractAddress;
  let fa12_12ContractAddress;
  let fa12_13ContractAddress;
  let fa12_14ContractAddress;
  let fa12_15ContractAddress;
  let fa12_16ContractAddress;
  let fa12_17ContractAddress;
  let fa12_18ContractAddress;
  let fa12_19ContractAddress;
  let fa12_20ContractAddress;
  let fa12_21ContractAddress;

  let interest0ContractAddress;
  let interest1ContractAddress;
  let interest2ContractAddress;
  let interest3ContractAddress;
  let interest4ContractAddress;
  let interest5ContractAddress;
  let interest6ContractAddress;
  let interest7ContractAddress;
  let interest8ContractAddress;
  let interest9ContractAddress;
  let interest10ContractAddress;
  let interest11ContractAddress;
  let interest12ContractAddress;
  let interest13ContractAddress;
  let interest14ContractAddress;
  let interest15ContractAddress;
  let interest16ContractAddress;
  let interest17ContractAddress;
  let interest18ContractAddress;
  let interest19ContractAddress;
  let interest20ContractAddress;
  let interest21ContractAddress;

  let yTokenContractAddress;
  let proxyContractAddress;
  let oracleContractAddress;

  before("setup Proxy", async () => {
    tezos = await Utils.initTezos();
    yToken = await YToken.originate(tezos);

    interest0 = await InterestRate.originate(tezos);
    interest1 = await InterestRate.originate(tezos);
    interest2 = await InterestRate.originate(tezos);
    interest3 = await InterestRate.originate(tezos);
    interest4 = await InterestRate.originate(tezos);
    interest5 = await InterestRate.originate(tezos);
    interest6 = await InterestRate.originate(tezos);
    interest7 = await InterestRate.originate(tezos);
    interest8 = await InterestRate.originate(tezos);
    interest9 = await InterestRate.originate(tezos);
    interest10 = await InterestRate.originate(tezos);
    interest11 = await InterestRate.originate(tezos);
    interest12 = await InterestRate.originate(tezos);
    interest13 = await InterestRate.originate(tezos);
    interest14 = await InterestRate.originate(tezos);
    interest15 = await InterestRate.originate(tezos);
    interest16 = await InterestRate.originate(tezos);
    interest17 = await InterestRate.originate(tezos);
    interest18 = await InterestRate.originate(tezos);
    interest19 = await InterestRate.originate(tezos);
    interest20 = await InterestRate.originate(tezos);
    interest21 = await InterestRate.originate(tezos);

    proxy = await Proxy.originate(tezos);
    oracle = await GetOracle.originate(tezos);

    fa12_0 = await FA12.originate(tezos);
    fa12_1 = await FA12.originate(tezos);
    fa12_2 = await FA12.originate(tezos);
    fa12_3 = await FA12.originate(tezos);
    fa12_4 = await FA12.originate(tezos);
    fa12_5 = await FA12.originate(tezos);
    fa12_6 = await FA12.originate(tezos);
    fa12_7 = await FA12.originate(tezos);
    fa12_8 = await FA12.originate(tezos);
    fa12_9 = await FA12.originate(tezos);
    fa12_10 = await FA12.originate(tezos);
    fa12_11 = await FA12.originate(tezos);
    fa12_12 = await FA12.originate(tezos);
    fa12_13 = await FA12.originate(tezos);
    fa12_14 = await FA12.originate(tezos);
    fa12_15 = await FA12.originate(tezos);
    fa12_16 = await FA12.originate(tezos);
    fa12_17 = await FA12.originate(tezos);
    fa12_18 = await FA12.originate(tezos);
    fa12_19 = await FA12.originate(tezos);
    fa12_20 = await FA12.originate(tezos);
    fa12_21 = await FA12.originate(tezos);

    yTokenContractAddress = yToken.contract.address;

    interest0ContractAddress = interest0.contract.address;
    interest1ContractAddress = interest1.contract.address;
    interest2ContractAddress = interest2.contract.address;
    interest3ContractAddress = interest3.contract.address;
    interest4ContractAddress = interest4.contract.address;
    interest5ContractAddress = interest5.contract.address;
    interest6ContractAddress = interest6.contract.address;
    interest7ContractAddress = interest7.contract.address;
    interest8ContractAddress = interest8.contract.address;
    interest9ContractAddress = interest9.contract.address;
    interest10ContractAddress = interest10.contract.address;
    interest11ContractAddress = interest11.contract.address;
    interest12ContractAddress = interest12.contract.address;
    interest13ContractAddress = interest13.contract.address;
    interest14ContractAddress = interest14.contract.address;
    interest15ContractAddress = interest15.contract.address;
    interest16ContractAddress = interest16.contract.address;
    interest17ContractAddress = interest17.contract.address;
    interest18ContractAddress = interest18.contract.address;
    interest19ContractAddress = interest19.contract.address;
    interest20ContractAddress = interest20.contract.address;
    interest21ContractAddress = interest21.contract.address;

    proxyContractAddress = proxy.contract.address;
    oracleContractAddress = oracle.contract.address;

    fa12_0ContractAddress = fa12_0.contract.address;
    fa12_1ContractAddress = fa12_1.contract.address;
    fa12_2ContractAddress = fa12_2.contract.address;
    fa12_3ContractAddress = fa12_3.contract.address;
    fa12_4ContractAddress = fa12_4.contract.address;
    fa12_5ContractAddress = fa12_5.contract.address;
    fa12_6ContractAddress = fa12_6.contract.address;
    fa12_7ContractAddress = fa12_7.contract.address;
    fa12_8ContractAddress = fa12_8.contract.address;
    fa12_9ContractAddress = fa12_9.contract.address;
    fa12_10ContractAddress = fa12_10.contract.address;
    fa12_11ContractAddress = fa12_11.contract.address;
    fa12_12ContractAddress = fa12_12.contract.address;
    fa12_13ContractAddress = fa12_13.contract.address;
    fa12_14ContractAddress = fa12_14.contract.address;
    fa12_15ContractAddress = fa12_15.contract.address;
    fa12_16ContractAddress = fa12_16.contract.address;
    fa12_17ContractAddress = fa12_17.contract.address;
    fa12_18ContractAddress = fa12_18.contract.address;
    fa12_19ContractAddress = fa12_19.contract.address;
    fa12_20ContractAddress = fa12_20.contract.address;
    fa12_21ContractAddress = fa12_21.contract.address;

    tezos = await Utils.setProvider(tezos, alice.sk);
    await Utils.trasferTo(tezos, carol.pkh, 50000000);
    await Utils.trasferTo(tezos, peter.pkh, 50000000);
    await Utils.trasferTo(tezos, dev.pkh, 50000000);
    await Utils.trasferTo(tezos, dev2.pkh, 50000000);

    await interest0.setCoefficients(
      800000000000000000,
      634195839,
      7134703196,
      31709791983
    );
    await interest0.updateStorage();

    await interest1.setCoefficients(
      800000000000000000,
      0,
      1585489599,
      34563673262
    );
    await interest1.updateStorage();

    await interest2.setCoefficients(
      800000000000000000,
      634195839,
      7134703196,
      31709791983
    );
    await interest2.updateStorage();

    await interest3.setCoefficients(
      800000000000000000,
      0,
      1585489599,
      34563673262
    );
    await interest3.updateStorage();

    await interest4.setCoefficients(
      800000000000000000,
      634195839,
      7134703196,
      31709791983
    );
    await interest4.updateStorage();

    await interest5.setCoefficients(
      800000000000000000,
      0,
      1585489599,
      34563673262
    );
    await interest5.updateStorage();

    await interest6.setCoefficients(
      800000000000000000,
      634195839,
      7134703196,
      31709791983
    );
    await interest6.updateStorage();

    await interest7.setCoefficients(
      800000000000000000,
      0,
      1585489599,
      34563673262
    );
    await interest7.updateStorage();

    await interest8.setCoefficients(
      800000000000000000,
      634195839,
      7134703196,
      31709791983
    );
    await interest8.updateStorage();

    await interest9.setCoefficients(
      800000000000000000,
      0,
      1585489599,
      34563673262
    );
    await interest9.updateStorage();

    await interest10.setCoefficients(
      800000000000000000,
      634195839,
      7134703196,
      31709791983
    );
    await interest10.updateStorage();

    await interest11.setCoefficients(
      800000000000000000,
      0,
      1585489599,
      34563673262
    );
    await interest11.updateStorage();

    await interest12.setCoefficients(
      800000000000000000,
      634195839,
      7134703196,
      31709791983
    );
    await interest12.updateStorage();

    await interest13.setCoefficients(
      800000000000000000,
      0,
      1585489599,
      34563673262
    );
    await interest13.updateStorage();

    await interest14.setCoefficients(
      800000000000000000,
      634195839,
      7134703196,
      31709791983
    );
    await interest14.updateStorage();

    await interest15.setCoefficients(
      800000000000000000,
      0,
      1585489599,
      34563673262
    );
    await interest15.updateStorage();

    await interest16.setCoefficients(
      800000000000000000,
      634195839,
      7134703196,
      31709791983
    );
    await interest16.updateStorage();

    await interest17.setCoefficients(
      800000000000000000,
      0,
      1585489599,
      34563673262
    );
    await interest17.updateStorage();

    await interest18.setCoefficients(
      800000000000000000,
      634195839,
      7134703196,
      31709791983
    );
    await interest18.updateStorage();

    await interest19.setCoefficients(
      800000000000000000,
      0,
      1585489599,
      34563673262
    );
    await interest19.updateStorage();

    await interest20.setCoefficients(
      800000000000000000,
      634195839,
      7134703196,
      31709791983
    );
    await interest20.updateStorage();

    await interest21.setCoefficients(
      800000000000000000,
      634195839,
      7134703196,
      31709791983
    );
    await interest21.updateStorage();

    await proxy.updateOracle(oracleContractAddress);
    await proxy.updateStorage();
    strictEqual(proxy.storage.oracle, oracleContractAddress);

    await proxy.updateYToken(yTokenContractAddress);
    await proxy.updateStorage();
    strictEqual(proxy.storage.yToken, yTokenContractAddress);

    await yToken.setGlobalFactors(
      "500000000000000000",
      "1050000000000000000",
      proxyContractAddress,
      "2"
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

  it("set yToken admin by admin", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await yToken.setAdmin(bob.pkh);
    await yToken.updateStorage();
    strictEqual(yToken.storage.storage.admin, bob.pkh);
  });

  it("add market [0]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest0ContractAddress,
      "fA12",
      fa12_0ContractAddress,
      0,
      650000000000000000,
      200000000000000000,
      5000000000000,
      tokenMetadata0
    );
    await yToken.updateStorage();

    await proxy.updatePair(0n, "COMP-USD");
    await proxy.updateStorage();
    strictEqual(await proxy.storage.pairName.get(0), "COMP-USD");

    let pairId = await proxy.storage.pairId.get("COMP-USD");
    strictEqual(pairId.toString(), "0");
  });

  it("add market [1]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest1ContractAddress,
      "fA12",
      fa12_1ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata1
    );
    await yToken.updateStorage();

    await proxy.updatePair(1, "XTZ-USD");
    await proxy.updateStorage();
    strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    let pairId = await proxy.storage.pairId.get("XTZ-USD");
    strictEqual(pairId.toString(), "1");
  });

  it("add market [2]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest2ContractAddress,
      "fA12",
      fa12_2ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata2
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });
  it("add market [3]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest3ContractAddress,
      "fA12",
      fa12_3ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata3
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });
  it("add market [4]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest4ContractAddress,
      "fA12",
      fa12_4ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata4
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });
  it("add market [5]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest5ContractAddress,
      "fA12",
      fa12_5ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata5
    );
    await yToken.updateStorage();
  });
  it("add market [6]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest6ContractAddress,
      "fA12",
      fa12_6ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata6
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });
  it("add market [7]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest7ContractAddress,
      "fA12",
      fa12_7ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata7
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });
  it("add market [8]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest8ContractAddress,
      "fA12",
      fa12_8ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata8
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });
  it("add market [9]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest9ContractAddress,
      "fA12",
      fa12_9ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata9
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });

  it("add market [10]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest10ContractAddress,
      "fA12",
      fa12_10ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata10
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });
  it("add market [11]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest11ContractAddress,
      "fA12",
      fa12_11ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata11
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });
  it("add market [12]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest12ContractAddress,
      "fA12",
      fa12_12ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata12
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });
  it("add market [13]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest13ContractAddress,
      "fA12",
      fa12_13ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata13
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });
  it("add market [14]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest14ContractAddress,
      "fA12",
      fa12_14ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata14
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });
  it("add market [15]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest15ContractAddress,
      "fA12",
      fa12_15ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata15
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });
  it("add market [16]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest16ContractAddress,
      "fA12",
      fa12_16ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata16
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });
  it("add market [17]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest17ContractAddress,
      "fA12",
      fa12_17ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata17
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });
  it("add market [18]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest18ContractAddress,
      "fA12",
      fa12_18ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata18
    );
    await yToken.updateStorage();

    // await proxy.updatePair(1, "XTZ-USD");
    // await proxy.updateStorage();
    // strictEqual(await proxy.storage.pairName.get(1), "XTZ-USD");

    // let pairId = await proxy.storage.pairId.get("XTZ-USD");
    // strictEqual(pairId.toString(), "1");
  });
  it("add market [19]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest19ContractAddress,
      "fA12",
      fa12_19ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata19
    );
    await yToken.updateStorage();
  });

  it("add market [20]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest20ContractAddress,
      "fA12",
      fa12_20ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata20
    );
    await yToken.updateStorage();
  });
  it("add market [21]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest21ContractAddress,
      "fA12",
      fa12_21ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata21
    );
    await yToken.updateStorage();
  });

  it("mint fa12_0 tokens by bob and peter", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await fa12_0.mint(10000000000000000000);
    await fa12_0.updateStorage();

    let res = await fa12_0.storage.ledger.get(bob.pkh);

    strictEqual(await res.balance.toString(), "10000000000000000000");

    tezos = await Utils.setProvider(tezos, peter.sk);
    await fa12_0.mint(10000000000000000000);
    await fa12_0.updateStorage();

    res = await fa12_0.storage.ledger.get(peter.pkh);

    strictEqual(await res.balance.toString(), "10000000000000000000");
  });

  it("mint fa12_1 by alice and carol", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await fa12_1.mint(10000000000000000000);
    await fa12_1.updateStorage();

    res = await fa12_1.storage.ledger.get(alice.pkh);

    strictEqual(await res.balance.toString(), "10000000000000000000");

    tezos = await Utils.setProvider(tezos, carol.sk);
    await fa12_1.mint(10000000000000000000);
    await fa12_1.updateStorage();

    res = await fa12_1.storage.ledger.get(carol.pkh);

    strictEqual(await res.balance.toString(), "10000000000000000000");
  });

  it("mint yTokens by alice", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await fa12_1.approve(yTokenContractAddress, 100000000000);
    await fa12_1.updateStorage();

    await yToken.updateAndMint(proxy, 1, 10000000000);
    await yToken.updateStorage();

    let res = await fa12_1.storage.ledger.get(alice.pkh);
    strictEqual(await res.balance.toString(), "9999999990000000000");

    let yTokenRes = await yToken.storage.storage.ledger.get([alice.pkh, 1]);

    strictEqual(
      yTokenRes.toPrecision(40).split(".")[0],
      "10000000000000000000000000000"
    );
  });

  it("mint yTokens by carol", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);
    await fa12_1.approve(yTokenContractAddress, 100000000000);
    await fa12_1.updateStorage();

    await yToken.updateAndMint(proxy, 1, 10000000000);
    await yToken.updateStorage();

    let res = await fa12_1.storage.ledger.get(carol.pkh);
    strictEqual(await res.balance.toString(), "9999999990000000000");

    let yTokenRes = await yToken.storage.storage.ledger.get([carol.pkh, 1]);
    let ytokens = await yToken.storage.storage.tokens.get("1");
    console.log(ytokens.lastPrice.toString());

    strictEqual(
      await yTokenRes.toPrecision(40).split(".")[0],
      "10000000000000000000000000000"
    );
  });

  it("mint yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await fa12_0.approve(yTokenContractAddress, 100000000000);
    await fa12_0.updateStorage();

    await yToken.updateAndMint2(proxy, 0, 100000);
    await yToken.updateStorage();

    let res = await fa12_0.storage.ledger.get(bob.pkh);
    strictEqual(await res.balance.toString(), "9999999999999900000");

    let yTokenRes = await yToken.storage.storage.ledger.get([bob.pkh, 0]);
    strictEqual(
      yTokenRes.toPrecision(40).split(".")[0],
      "100000000000000000000000"
    );
  });

  it("mint yTokens by peter", async () => {
    tezos = await Utils.setProvider(tezos, peter.sk);
    await fa12_0.approve(yTokenContractAddress, 100000000000);
    await fa12_0.updateStorage();

    await yToken.updateAndMint2(proxy, 0, 1000);
    await yToken.updateStorage();

    let res = await fa12_0.storage.ledger.get(peter.pkh);
    strictEqual(await res.balance.toString(), "9999999999999999000");

    let yTokenRes = await yToken.storage.storage.ledger.get([peter.pkh, 0]);
    strictEqual(
      yTokenRes.toPrecision(40).split(".")[0],
      "1000000000000000000000"
    );
  });

  it("enterMarket [0] by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await yToken.enterMarket(0);
    await yToken.updateStorage();
    res = await yToken.storage.storage.markets.get(bob.pkh);
    strictEqual(res.toString(), "0");
  });

  it("enterMarket [0] by peter", async () => {
    tezos = await Utils.setProvider(tezos, peter.sk);

    await yToken.enterMarket(0);
    await yToken.updateStorage();
    res = await yToken.storage.storage.markets.get(peter.pkh);
    strictEqual(res.toString(), "0");
  });

  it("borrow yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.updateAndBorrow(proxy, 1, 50000);
    await yToken.updateStorage();

    res = await yToken.storage.storage.accounts.get([bob.pkh, 1]);
    strictEqual(
      res.borrow.toPrecision(40).split(".")[0],
      "50000000000000000000000"
    );
  });

  it("borrow yTokens by bob (2)", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await Utils.bakeBlocks(tezos, 7);

    await yToken.updateAndBorrow(proxy, 1, 1000);
    await yToken.updateStorage();

    let res = await yToken.storage.storage.accounts.get([bob.pkh, 1]);
    console.log(res.borrow.toPrecision(40).split(".")[0]); // not static result
  });

  it("redeem 0 by carol", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);
    await yToken.updateAndRedeem(proxy, 1, 0);
    await yToken.updateStorage();

    let yTokenRes = await yToken.storage.storage.ledger.get([carol.pkh, 1]);
    console.log(yTokenRes.toPrecision(40).split(".")[0]);
  });

  it("mint yTokens by carol", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);

    await yToken.updateAndMint(proxy, 1, 10000000000);
    await yToken.updateStorage();

    let yTokenRes = await yToken.storage.storage.ledger.get([carol.pkh, 1]);
    console.log(yTokenRes.toPrecision(40).split(".")[0]);
  });

  it("borrow yTokens by peter", async () => {
    tezos = await Utils.setProvider(tezos, peter.sk);
    await yToken.updateAndBorrow(proxy, 1, 500);
    await yToken.updateStorage();

    res = await yToken.storage.storage.accounts.get([peter.pkh, 1]);

    strictEqual(
      res.borrow.toPrecision(40).split(".")[0],
      "500000000000000000000"
    );
  });

  it("repay yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await fa12_1.approve(yTokenContractAddress, 100000);
    await fa12_1.updateStorage();

    await yToken.updateAndRepay(proxy, 1, 40000);
    await yToken.updateStorage();

    let yTokenRes = await yToken.storage.storage.accounts.get([bob.pkh, 1]);
    console.log(yTokenRes.borrow.toPrecision(40).split(".")[0]); // not static result
  });

  it("repay 5 yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await fa12_2.mint(10000);
    await fa12_2.updateStorage();

    let res = await fa12_2.storage.ledger.get(bob.pkh);
    console.log(await res.balance.toString()); // not static result

    let yTokenRes = await yToken.storage.storage.accounts.get([bob.pkh, 1]);
    console.log(yTokenRes.borrow.toPrecision(40).split(".")[0]); // not static result

    await yToken.updateAndRepay(proxy, 1, 0);
    await yToken.updateStorage();

    yTokenRes = await yToken.storage.storage.accounts.get([bob.pkh, 1]);
    strictEqual(yTokenRes.borrow.toString(), "0");
  });

  it("exit market yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    let res = await yToken.storage.storage.markets.get(bob.pkh);
    strictEqual(await res.toString(), "0");

    await yToken.updateAndExit(proxy, 0);
    await yToken.updateStorage();

    res = await yToken.storage.storage.markets.get(bob.pkh);
    strictEqual(await res.toString(), "");
  });
});
