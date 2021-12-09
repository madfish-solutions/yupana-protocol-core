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
// var bigInt = require("big-integer");

const { Proxy } = require("../test/utils/proxy");
const { InterestRate } = require("../test/utils/interestRate");
const { GetOracle } = require("../test/utils/getOracle");
const { YToken } = require("../test/utils/yToken");
const { FA12 } = require("../test/utils/fa12");
const { FA2 } = require("../test/utils/fa2");
const { Utils } = require("../test/utils/utils");

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

describe("yToken tests", async () => {
  let tezos;
  let yToken;
  let interest;
  let interest2;
  let proxy;
  let oracle;
  let fa12;
  let fa12_2;
  let fa2;
  let fa2_2;
  let yTokenContractAddress;
  let interestContractAddress;
  let proxyContractAddress;
  let oracleContractAddress;
  let fa12ContractAddress;
  let fa2ContractAddress;
  let fa2_2ContractAddress;

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
    fa2_2 = await FA2.originate(tezos);

    yTokenContractAddress = yToken.contract.address;
    interestContractAddress = interest.contract.address;
    interest2ContractAddress = interest2.contract.address;
    proxyContractAddress = proxy.contract.address;
    oracleContractAddress = oracle.contract.address;
    fa12ContractAddress = fa12.contract.address;
    fa12_2ContractAddress = fa12_2.contract.address;
    fa2ContractAddress = fa2.contract.address;
    fa2_2ContractAddress = fa2_2.contract.address;

    tezos = await Utils.setProvider(tezos, alice.sk);
    await Utils.trasferTo(tezos, carol.pkh, 50000000);
    await Utils.trasferTo(tezos, peter.pkh, 50000000);
    await Utils.trasferTo(tezos, dev.pkh, 50000000);
    await Utils.trasferTo(tezos, dev2.pkh, 50000000);

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
      "2",
      "550000000000000000"
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
    tezos = await Utils.setProvider(tezos, bob.sk);
    await rejects(yToken.setAdmin(carol.pkh), (err) => {
      ok(err.message == "yToken/not-admin", "Error message mismatch");
      return true;
    });
  });

  it("set yToken admin by admin", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await yToken.setAdmin(bob.pkh);
    await yToken.updateStorage();
    strictEqual(yToken.storage.storage.admin, bob.pkh);
  });

  it("add market [0] by non admin", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await rejects(
      yToken.addMarket(
        interestContractAddress,
        "fA12",
        fa12ContractAddress,
        0,
        500000000000000000,
        500000000000000000,
        5000000000000,
        tokenMetadata
      ),
      (err) => {
        ok(err.message == "yToken/not-admin", "Error message mismatch");
        return true;
      }
    );
  });

  it("add market [0] by admin", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interest2ContractAddress,
      "fA12",
      fa12ContractAddress,
      0,
      650000000000000000,
      200000000000000000,
      5000000000000,
      tokenMetadata
    );
    await yToken.updateStorage();

    await proxy.updatePair(0n, "COMP-USD");
    await proxy.updateStorage();
    strictEqual(await proxy.storage.pairName.get(0), "COMP-USD");

    let pairId = await proxy.storage.pairId.get("COMP-USD");
    strictEqual(pairId.toString(), "0");
  });

  it("add market [0] by admin one more time", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await rejects(
      yToken.addMarket(
        interest2ContractAddress,
        "fA12",
        fa12ContractAddress,
        0,
        750000000000000000,
        400000000000000000,
        9000000000000,
        tokenMetadata
      ),
      (err) => {
        ok(
          err.message == "yToken/token-has-already-been-added",
          "Error message mismatch"
        );
        return true;
      }
    );
  });

  it("update metadata [0] by non admin", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await rejects(yToken.updateMetadata(0, tokenMetadata2), (err) => {
      ok(err.message == "yToken/not-admin", "Error message mismatch");
      return true;
    });
  });

  it("update metadata [0] by admin", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.updateMetadata(0, tokenMetadata2);
    await yToken.updateStorage();
  });

  it("add market [1]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interestContractAddress,
      "fA12",
      fa12_2ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata
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
      interestContractAddress,
      "fA2",
      fa2ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata
    );
    await yToken.updateStorage();

    await proxy.updatePair(2, "BTC-USD");
    await proxy.updateStorage();
    strictEqual(await proxy.storage.pairName.get(2), "BTC-USD");

    let pairId = await proxy.storage.pairId.get("BTC-USD");
    strictEqual(pairId.toString(), "2");

    await fa2.create_token(tokenMetadata);
    await fa2.updateStorage();
  });

  it("add market [3]", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.addMarket(
      interestContractAddress,
      "fA2",
      fa2_2ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata2
    );
    await yToken.updateStorage();

    await fa2_2.create_token(tokenMetadata2);
    await fa2_2.updateStorage();

    await proxy.updatePair(3, "ETH-USD");
    await proxy.updateStorage();
    strictEqual(await proxy.storage.pairName.get(3), "ETH-USD");

    let pairId = await proxy.storage.pairId.get("ETH-USD");
    strictEqual(pairId.toString(), "3");
  });

  it("set borrow pause by alice", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);

    await rejects(yToken.setBorrowPause(2, true), (err) => {
      ok(err.message == "yToken/not-admin", "Error message mismatch");
      return true;
    });
  });

  it("set borrow pause by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    let res = await yToken.storage.storage.tokens.get("1");
    strictEqual(res.borrowPause, false);

    await yToken.setBorrowPause(1, true);
    await yToken.updateStorage();

    res = await yToken.storage.storage.tokens.get("1");
    strictEqual(res.borrowPause, true);
  });

  it("mint fa12 tokens by bob and peter", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await fa12.mint(10000000000000000000);
    await fa12.updateStorage();

    let res = await fa12.storage.ledger.get(bob.pkh);

    strictEqual(await res.balance.toString(), "10000000000000000000");

    tezos = await Utils.setProvider(tezos, peter.sk);
    await fa12.mint(10000000000000000000);
    await fa12.updateStorage();

    res = await fa12.storage.ledger.get(peter.pkh);

    strictEqual(await res.balance.toString(), "10000000000000000000");
  });

  it("mint fa12_2 by alice and carol", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await fa12_2.mint(10000000000000000000);
    await fa12_2.updateStorage();

    res = await fa12_2.storage.ledger.get(alice.pkh);

    strictEqual(await res.balance.toString(), "10000000000000000000");

    tezos = await Utils.setProvider(tezos, carol.sk);
    await fa12_2.mint(10000000000000000000);
    await fa12_2.updateStorage();

    res = await fa12_2.storage.ledger.get(carol.pkh);

    strictEqual(await res.balance.toString(), "10000000000000000000");
  });

  it("mint non-existent yToken by alice", async () => {
    await rejects(yToken.mint(32, 1000000), (err) => {
      ok(err.message == "yToken/yToken-undefined", "Error message mismatch");
      return true;
    });
  });

  it("mint zero yToken by alice", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await rejects(yToken.mint(1, 0), (err) => {
      ok(err.message == "yToken/amount-is-zero", "Error message mismatch");
      return true;
    });
  });

  it("mint fa2 by dev", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await fa2.mint([
      { token_id: 0, receiver: dev.pkh, amount: 10000000000000000000 },
    ]);
    await fa2.updateStorage();

    let res = await fa2.storage.account_info.get(dev.pkh);
    strictEqual(await res.balances.get("0").toString(), "10000000000000000000");
  });

  it("mint fa2_2 by dev2", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await fa2_2.mint([
      { token_id: 0, receiver: dev2.pkh, amount: 10000000000000000000 },
    ]);
    await fa2_2.updateStorage();

    let res = await fa2_2.storage.account_info.get(dev2.pkh);
    strictEqual(await res.balances.get("0").toString(), "10000000000000000000");
  });

  it("mint yTokens by alice", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await fa12_2.approve(yTokenContractAddress, 100000000000);
    await fa12_2.updateStorage();

    await yToken.mint(1, 10000000000);
    await yToken.updateStorage();

    let res = await fa12_2.storage.ledger.get(alice.pkh);
    strictEqual(await res.balance.toString(), "9999999990000000000");

    let yTokenRes = await yToken.storage.storage.ledger.get([alice.pkh, 1]);

    strictEqual(
      yTokenRes.toPrecision(40).split(".")[0],
      "10000000000000000000000000000"
    );
  });

  it("mint yTokens by carol", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);
    await fa12_2.approve(yTokenContractAddress, 100000000000);
    await fa12_2.updateStorage();

    await yToken.updateAndMint(proxy, 1, 10000000000);
    await yToken.updateStorage();

    let res = await fa12_2.storage.ledger.get(carol.pkh);
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
    await fa12.approve(yTokenContractAddress, 100000000000);
    await fa12.updateStorage();

    await yToken.mint(0, 100000);
    await yToken.updateStorage();

    let res = await fa12.storage.ledger.get(bob.pkh);
    strictEqual(await res.balance.toString(), "9999999999999900000");

    let yTokenRes = await yToken.storage.storage.ledger.get([bob.pkh, 0]);
    strictEqual(
      yTokenRes.toPrecision(40).split(".")[0],
      "100000000000000000000000"
    );
  });

  it("mint yTokens by peter", async () => {
    tezos = await Utils.setProvider(tezos, peter.sk);
    await fa12.approve(yTokenContractAddress, 100000000000);
    await fa12.updateStorage();

    await yToken.updateAndMint2(proxy, 0, 1000);
    await yToken.updateStorage();

    let res = await fa12.storage.ledger.get(peter.pkh);
    strictEqual(await res.balance.toString(), "9999999999999999000");

    let yTokenRes = await yToken.storage.storage.ledger.get([peter.pkh, 0]);
    strictEqual(
      yTokenRes.toPrecision(40).split(".")[0],
      "1000000000000000000000"
    );
  });

  it("mint yTokens [2] by dev", async () => {
    tezos = await Utils.setProvider(tezos, dev.sk);
    await fa2.update_operators([
      {
        add_operator: {
          owner: dev.pkh,
          operator: yTokenContractAddress,
          token_id: 0,
        },
      },
    ]);
    await fa2.updateStorage();

    await yToken.updateAndMint2(proxy, 2, 1000);
    await yToken.updateStorage();

    let res = await fa2.storage.account_info.get(dev.pkh);
    let res2 = await res.balances.get("0");
    strictEqual(await res2.toString(), "9999999999999999000");

    let yTokenRes = await yToken.storage.storage.ledger.get([dev.pkh, 2]);
    strictEqual(
      yTokenRes.toPrecision(40).split(".")[0],
      "1000000000000000000000"
    );
  });

  it("mint yTokens [3] by dev2", async () => {
    tezos = await Utils.setProvider(tezos, dev2.sk);
    await fa2_2.update_operators([
      {
        add_operator: {
          owner: dev2.pkh,
          operator: yTokenContractAddress,
          token_id: 0,
        },
      },
    ]);
    await fa2_2.updateStorage();

    await yToken.updateAndMint2(proxy, 3, 100000000);
    await yToken.updateStorage();

    let res = await fa2_2.storage.account_info.get(dev2.pkh);
    let res2 = await res.balances.get("0");
    strictEqual(await res2.toString(), "9999999999900000000");

    let yTokenRes = await yToken.storage.storage.ledger.get([dev2.pkh, 3]);
    strictEqual(
      yTokenRes.toPrecision(40).split(".")[0],
      "100000000000000000000000000"
    );
  });

  it("update Interest Rate yToken undefined", async () => {
    await rejects(yToken.updateInterest(4), (err) => {
      ok(err.message == "yToken/yToken-undefined", "Error message mismatch");
      return true;
    });
  });

  it("return price by not oracle", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await rejects(yToken.priceCallback(0, 2000), (err) => {
      ok(err.message == "yToken/sender-is-not-price-feed", "Error message mismatch");
      return true;
    });
  });

  it("borrow when token forbidden for borrow bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await rejects(yToken.updateAndBorrow(proxy, 1, 50000), (err) => {
      ok(
        err.message == "yToken/forbidden-for-borrow",
        "Error message mismatch"
      );
      return true;
    });
  });

  it("unset borrow pause by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.setBorrowPause(1, false);
    await yToken.updateStorage();

    let res = await yToken.storage.storage.tokens.get("1");
    strictEqual(res.borrowPause, false);
  });

  it("borrow when not enter market by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await rejects(yToken.updateAndBorrow(proxy, 1, 50000), (err) => {
      ok(
        err.message == "yToken/exceeds-the-permissible-debt",
        "Error message mismatch"
      );
      return true;
    });
  });

  it("(should fail not operator) transfer alice to bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await rejects(
      yToken.transfer([
        {
          from_: alice.pkh,
          txs: [{ to_: bob.pkh, token_id: 1, amount: 100 }],
        },
      ]),
      (err) => {
        ok(err.message == "FA2_NOT_OPERATOR", "Error message mismatch");
        return true;
      }
    );
  });

  it("(should fail insufficient balance) transfer alice to bob", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);

    await rejects(
      yToken.transfer([
        {
          from_: alice.pkh,
          txs: [{ to_: bob.pkh, token_id: 0, amount: 100 }],
        },
      ]),
      (err) => {
        ok(err.message == "FA2_INSUFFICIENT_BALANCE", "Error message mismatch");
        return true;
      }
    );
  });

  it("(should fail undefined token) transfer alice to bob", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);

    await rejects(
      yToken.transfer([
        {
          from_: alice.pkh,
          txs: [{ to_: bob.pkh, token_id: 1111, amount: 100 }],
        },
      ]),
      (err) => {
        ok(err.message == "FA2_TOKEN_UNDEFINED", "Error message mismatch");
        return true;
      }
    );
  });

  it("transfer alice to bob", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    let res = await yToken.storage.storage.ledger.get([bob.pkh, 1]);
    strictEqual(res, undefined);

    let res2 = await yToken.storage.storage.ledger.get([alice.pkh, 1]);
    strictEqual(
      res2.toPrecision(40).split(".")[0],
      "10000000000000000000000000000"
    );

    await yToken.transfer([
      {
        from_: alice.pkh,
        txs: [{ to_: bob.pkh, token_id: 1, amount: 100 }],
      },
    ]);
    await yToken.updateStorage();

    res = await yToken.storage.storage.ledger.get([bob.pkh, 1]);
    strictEqual(res.toPrecision(40).split(".")[0], "100000000000000000000");

    res2 = await yToken.storage.storage.ledger.get([alice.pkh, 1]);
    strictEqual(
      res2.toPrecision(40).split(".")[0],
      "9999999900000000000000000000"
    );
  });

  it("add operator alice to bob", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);

    await yToken.update_operators([
      {
        add_operator: {
          owner: alice.pkh,
          operator: bob.pkh,
          token_id: 1,
        },
      },
    ]);
    await yToken.updateStorage();

    let res = await yToken.storage.storage.accounts.get([alice.pkh, 1]);
    strictEqual(res.allowances.toString(), `${bob.pkh}`);
  });

  it("add operator (should fail not owner)", async () => {
    tezos = await Utils.setProvider(tezos, peter.sk);

    await rejects(
      yToken.update_operators([
        {
          add_operator: {
            owner: alice.pkh,
            operator: peter.pkh,
            token_id: 1,
          },
        },
      ]),
      (err) => {
        ok(err.message == "FA2_NOT_OWNER", "Error message mismatch");
        return true;
      }
    );
  });

  it("add operator alice to peter", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);

    await yToken.update_operators([
      {
        add_operator: {
          owner: alice.pkh,
          operator: peter.pkh,
          token_id: 1,
        },
      },
    ]);
    await yToken.updateStorage();

    let res = await yToken.storage.storage.accounts.get([alice.pkh, 1]);
    strictEqual(res.allowances.toString(), `${peter.pkh},${bob.pkh}`);
  });

  it("remove operator alice to peter", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);

    await yToken.update_operators([
      {
        remove_operator: {
          owner: alice.pkh,
          operator: peter.pkh,
          token_id: 1,
        },
      },
    ]);
    await yToken.updateStorage();

    let res = await yToken.storage.storage.accounts.get([alice.pkh, 1]);
    strictEqual(res.allowances.toString(), `${bob.pkh}`);
  });

  it("transfer alice to bob by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    let res = await yToken.storage.storage.ledger.get([bob.pkh, 1]);
    strictEqual(res.toPrecision(40).split(".")[0], "100000000000000000000");

    let res2 = await yToken.storage.storage.ledger.get([alice.pkh, 1]);
    strictEqual(
      res2.toPrecision(40).split(".")[0],
      "9999999900000000000000000000"
    );

    await yToken.transfer([
      {
        from_: alice.pkh,
        txs: [{ to_: bob.pkh, token_id: 1, amount: 100 }],
      },
    ]);
    await yToken.updateStorage();

    res = await yToken.storage.storage.ledger.get([bob.pkh, 1]);
    strictEqual(res.toPrecision(40).split(".")[0], "200000000000000000000");

    res2 = await yToken.storage.storage.ledger.get([alice.pkh, 1]);
    strictEqual(
      res2.toPrecision(40).split(".")[0],
      "9999999800000000000000000000"
    );
  });

  it("enterMarket [0] by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await yToken.enterMarket(0);
    await yToken.updateStorage();
    await yToken.enterMarket(1);
    await yToken.updateStorage();
    await rejects(yToken.enterMarket(2), (err) => {
      ok(err.message == "yToken/max-market-limit", "Error message mismatch");
      return true;
    });
    res = await yToken.storage.storage.markets.get(bob.pkh);
    strictEqual(res.toString(), "0,1");
  });

  it("setGlobalFactors update maxMarket", async () => {
    await yToken.setGlobalFactors(
      "500000000000000000",
      "1050000000000000000",
      proxyContractAddress,
      "10",
      "550000000000000000"
    );
    await yToken.updateStorage();
    strictEqual(yToken.storage.storage.priceFeedProxy, proxyContractAddress);
  });

  it("exit market yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await yToken.updateAndExit2(proxy, 1);
    await yToken.updateStorage();

    res = await yToken.storage.storage.markets.get(bob.pkh);
    strictEqual(res.toString(), "0");
  });

  it("enterMarket non-existent yToken by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await rejects(yToken.enterMarket(4), (err) => {
      ok(err.message == "yToken/yToken-undefined", "Error message mismatch");
      return true;
    });
  });

  it("enterMarket [0] by peter", async () => {
    tezos = await Utils.setProvider(tezos, peter.sk);

    await yToken.enterMarket(0);
    await yToken.updateStorage();
    res = await yToken.storage.storage.markets.get(peter.pkh);
    strictEqual(res.toString(), "0");
  });

  it("enterMarket [3] by dev2", async () => {
    tezos = await Utils.setProvider(tezos, dev2.sk);

    await yToken.enterMarket(3);
    await yToken.updateStorage();
    res = await yToken.storage.storage.markets.get(dev2.pkh);
    strictEqual(res.toString(), "3");
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

  it("redeem borrowed yTokens by alice", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await rejects(yToken.updateAndRedeem(proxy, 1, 0), (err) => {
      ok(err.message == "underflow/totalLiquidF", "Error message mismatch");
      return true;
    });
  });

  it("try to mint without updateInterest yTokens by carol", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);
    await rejects(yToken.mint(1, 10000000000), (err) => {
      ok(err.message == "yToken/need-update", "Error message mismatch");
      return true;
    });
  });

  it("mint yTokens by carol", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);

    await yToken.updateAndMint(proxy, 1, 10000000000);
    await yToken.updateStorage();

    let yTokenRes = await yToken.storage.storage.ledger.get([carol.pkh, 1]);
    console.log(yTokenRes.toPrecision(40).split(".")[0]);
  });

  it("redeem more than allowed yTokens by carol", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);
    await rejects(yToken.updateAndRedeem(proxy, 1, 19000000000), (err) => {
      ok(
        err.message == "yToken/not-enough-tokens-to-burn",
        "Error message mismatch"
      );
      return true;
    });
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

  it("borrow yTokens by dev2", async () => {
    tezos = await Utils.setProvider(tezos, dev2.sk);
    await yToken.updateAndBorrow(proxy, 3, 1000);
    await yToken.updateStorage();

    res = await yToken.storage.storage.accounts.get([dev2.pkh, 3]);

    strictEqual(
      res.borrow.toPrecision(40).split(".")[0],
      "1000000000000000000000"
    );
  });

  it("borrow more than allowed yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await rejects(yToken.updateAndBorrow(proxy, 1, 20000000), (err) => {
      ok(
        err.message == "yToken/exceeds-the-permissible-debt",
        "Error message mismatch"
      );
      return true;
    });
  });

  it("borrow more than allowed yTokens by alice", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);

    await rejects(yToken.updateAndBorrow2(proxy, 0, 20000000000), (err) => {
      ok(
        err.message == "yToken/exceeds-the-permissible-debt",
        "Error message mismatch"
      );
      return true;
    });
  });

  it("repay more than has yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await fa12_2.approve(yTokenContractAddress, 100000);
    await fa12_2.updateStorage();

    await rejects(yToken.updateAndRepay(proxy, 1, 20000000000), (err) => {
      ok(
        err.message == "yToken/cant-repay-more-than-borrowed",
        "Error message mismatch"
      );
      return true;
    });
  });

  it("repay yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await yToken.updateAndRepay(proxy, 1, 40000);
    await yToken.updateStorage();

    let yTokenRes = await yToken.storage.storage.accounts.get([bob.pkh, 1]);
    console.log(yTokenRes.borrow.toPrecision(40).split(".")[0]); // not static result
  });

  it("repay yTokens by dev2", async () => {
    tezos = await Utils.setProvider(tezos, dev2.sk);

    await yToken.updateAndRepay(proxy, 3, 0);
    await yToken.updateStorage();

    let yTokenRes = await yToken.storage.storage.accounts.get([dev2.pkh, 3]);
    strictEqual(yTokenRes.borrow.toPrecision(40).split(".")[0], "0");
  });

  it("exit market yTokens by dev2", async () => {
    tezos = await Utils.setProvider(tezos, dev2.sk);

    let res = await yToken.storage.storage.markets.get(dev2.pkh);
    strictEqual(await res.toString(), "3");

    await yToken.updateAndExit(proxy, 3);
    await yToken.updateStorage();

    res = await yToken.storage.storage.markets.get(dev2.pkh);
    strictEqual(await res.toString(), "");
  });

  it("redeem 3 by dev2", async () => {
    tezos = await Utils.setProvider(tezos, dev2.sk);
    await yToken.updateAndRedeem(proxy, 3, 0);
    await yToken.updateStorage();

    let yTokenRes = await yToken.storage.storage.ledger.get([dev2.pkh, 3]);
    console.log(yTokenRes.toPrecision(40).split(".")[0]); // not static result
  });

  it("redeem by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.updateAndRedeem(proxy, 0, 100);
    await yToken.updateStorage();

    let yTokenRes = await yToken.storage.storage.ledger.get([bob.pkh, 1]);
    console.log(yTokenRes.toPrecision(40).split(".")[0]); // not static result
  });

  it("redeem yTokens by bob (exceeds-allowable-redeem)", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await rejects(yToken.updateAndRedeem(proxy, 0, 0), (err) => {
      ok(
        err.message == "yToken/exceeds-allowable-redeem",
        "Error message mismatch"
      );
      return true;
    });
  });

  it("try exit market yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await rejects(yToken.updateAndExit(proxy, 0), (err) => {
      ok(err.message == "yToken/debt-not-repaid", "Error message mismatch");
      return true;
    });
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

  it("liquidate not achieved", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);
    await rejects(yToken.updateAndLiq(proxy, 1, 0, peter.pkh, 250), (err) => {
      ok(
        err.message == "yToken/liquidation-not-achieved",
        "Error message mismatch"
      );
      return true;
    });
  });

  it("setTokenFactors by non admin", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);
    await rejects(
      yToken.setTokenFactors(0, 0, 0, interestContractAddress, 0),
      (err) => {
        ok(err.message == "yToken/not-admin", "Error message mismatch");
        return true;
      }
    );
  });

  it("setTokenFactors (collateralFactor = 0) by admin", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.updateAndsetTokenFactors(
      proxy,
      0,
      0,
      200000000000000000,
      interest2ContractAddress,
      5000000000000
    );
    await yToken.updateStorage();
  });

  it("setGlobalFactors (threshold = 0) by admin", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.setGlobalFactors(
      "500000000000000000",
      "1050000000000000000",
      proxyContractAddress,
      "2",
      "0"
    );
    await yToken.updateStorage();
  });

  it("liquidate by carol (collateral factor 0)", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);

    await yToken.updateAndLiq(proxy, 1, 0, peter.pkh, 250);
    await yToken.updateStorage();

    yTokenRes = await yToken.storage.storage.ledger.get([peter.pkh, 0]);
    console.log(yTokenRes.toPrecision(40).split(".")[0]); // not static result

    res = await yToken.storage.storage.accounts.get([peter.pkh, 1]);
    console.log(res.borrow.toPrecision(40).split(".")[0]); // not static result
  });

  it("setTokenFactors (return collateralFactor) by admin", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.updateAndsetTokenFactors(
      proxy,
      0,
      650000000000000000,
      200000000000000000,
      interest2ContractAddress,
      5000000000000
    );
    await yToken.updateStorage();
  });

  it("setGlobalFactors (return threshold) by admin", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.setGlobalFactors(
      "500000000000000000",
      "1050000000000000000",
      proxyContractAddress,
      "2",
      "550000000000000000"
    );
    await yToken.updateStorage();
  });

  it("liquidate not achieved", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);
    await rejects(yToken.updateAndLiq(proxy, 1, 0, peter.pkh, 100), (err) => {
      ok(
        err.message == "yToken/liquidation-not-achieved",
        "Error message mismatch"
      );
      return true;
    });
  });

  it("update price", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await oracle.updateStorage();

    await oracle.update(
      MichelsonMap.fromLiteral({
        ["XTZ-USD"]: [
          "2021-10-23T07:01:00Z",
          "2021-10-23T07:02:00Z",
          321748180,
          321748180,
          321748180,
          321748180,
          2,
        ],
      })
    );
    await oracle.updateStorage();

    let res = await oracle.storage.assetMap.get("COMP-USD");
    strictEqual(res.computedPrice.toPrecision(40).split(".")[0], "321748180");

    await oracle.update(
      MichelsonMap.fromLiteral({
        ["COMP-USD"]: [
          "2021-10-23T07:01:00Z",
          "2021-10-23T07:02:00Z",
          100874090,
          100874090,
          100874090,
          100874090,
          2,
        ],
      })
    );

    await oracle.updateStorage();

    res = await oracle.storage.assetMap.get("COMP-USD");
    strictEqual(res.computedPrice.toPrecision(40).split(".")[0], "100874090");
  });

  it("liquidate by carol 2 (collateral price fell)", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);

    await yToken.updateAndLiq(proxy, 1, 0, peter.pkh, 100);
    await yToken.updateStorage();

    yTokenRes = await yToken.storage.storage.ledger.get([peter.pkh, 0]);
    console.log(yTokenRes.toPrecision(40).split(".")[0]); // not static result

    res = await yToken.storage.storage.accounts.get([peter.pkh, 1]);
    console.log(res.borrow.toPrecision(40).split(".")[0]); // not static result
  });

  it("liquidate by carol 3 (collateral price fell)", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);

    await yToken.updateAndLiq(proxy, 1, 0, peter.pkh, 75);
    await yToken.updateStorage();

    yTokenRes = await yToken.storage.storage.ledger.get([peter.pkh, 0]);
    console.log(yTokenRes.toPrecision(40).split(".")[0]); // not static result

    res = await yToken.storage.storage.accounts.get([peter.pkh, 1]);
    console.log(res.borrow.toPrecision(40).split(".")[0]); // not static result
  });

  it("liquidate by carol 4 (collateral price fell)", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);

    await yToken.updateAndLiq(proxy, 1, 0, peter.pkh, 35);
    await yToken.updateStorage();

    yTokenRes = await yToken.storage.storage.ledger.get([peter.pkh, 0]);
    console.log(yTokenRes.toPrecision(40).split(".")[0]); // not static result

    res = await yToken.storage.storage.accounts.get([peter.pkh, 1]);
    console.log(res.borrow.toPrecision(40).split(".")[0]); // not static result
  });

  it("liquidation not achieved", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);
    await rejects(yToken.updateAndLiq(proxy, 1, 0, peter.pkh, 15), (err) => {
      ok(
        err.message == "yToken/liquidation-not-achieved",
        "Error message mismatch"
      );
      return true;
    });
  });
});
