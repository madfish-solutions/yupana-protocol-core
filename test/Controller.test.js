const { MichelsonMap } = require("@taquito/michelson-encoder");
const truffleAssert = require('truffle-assertions');
const BigNumber = require('bignumber.js');
const { execSync } = require("child_process");

const { accounts } = require("../scripts/sandbox/accounts");
const { revertDefaultSigner } = require( "./helpers/signerSeter");
const { setSigner } = require( "./helpers/signerSeter");

const DAI = artifacts.require("qToken");
const Controller = artifacts.require("Controller");

const toBN = (num) => {
  return new BigNumber(num);
};

const Fixed = (value) => {
  return value.toNumber().toLocaleString('fullwide', {useGrouping:false})
};

contract.only("Controller", async () => {
  const accuracy =  toBN(1e+18);

  const ZERO_ADDRESS = "tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg";
  const DEFAULT = accounts[0];
  const ADMIN = accounts[1];
  const FACTORY = accounts[2];
  const USER = accounts[3];

  const underlyingToken = accounts[4];
  const qToken = accounts[5];
  const qTokenORACLE = accounts[6];

  const qTokens = [qToken];

  const pairs = MichelsonMap.fromLiteral({
    [underlyingToken]: qToken,
  });

  const accBorrows = new MichelsonMap();
  accBorrows.set({ user: USER, token: ZERO_ADDRESS}, 0);

  const accTokens = new MichelsonMap();
  accTokens.set({ user: USER, token: ZERO_ADDRESS}, 0);

  const qTokenCollateralFactor = accuracy.multipliedBy(15);
  const qTokenLastPrice = accuracy.multipliedBy(20);
  const qTokenExchangeRate = accuracy.multipliedBy(5);
  const markets = MichelsonMap.fromLiteral({
    [qToken]: {
      collateralFactor: qTokenCollateralFactor,
      lastPrice: qTokenLastPrice,
      oracle: qTokenORACLE,
      exchangeRate: qTokenExchangeRate,
    },
  });

  const accountMembership = MichelsonMap.fromLiteral({
    [USER]: [qToken],
  })

  let DAI_Instance;
  let Controller_Instance;
  let DAI_Storage;
  let storage;
  let fullStorage;

  beforeEach("setup", async () => {
    DAI_Storage = {
      owner:          DEFAULT,
      admin:          DEFAULT,
      token:          DEFAULT,
      lastUpdateTime: "2000-01-01T10:10:10.000Z",
      totalBorrows:   0,
      totalLiquid:    0,
      totalSupply:    0,
      totalReserves:  0,
      borrowIndex:    0,
      accountBorrows: MichelsonMap.fromLiteral({
        [DEFAULT]: {
          amount:          0,
          lastBorrowIndex: 0,
        }
      }),
      accountTokens:  MichelsonMap.fromLiteral({
        [DEFAULT]: 0,
      }),
    };
    DAI_Instance = await DAI.new(DAI_Storage);

    storage = {
      factory: FACTORY,
      admin: ADMIN,
      qTokens: qTokens,
      pairs: pairs,
      accountBorrows: accBorrows,
      accountTokens: accTokens,
      markets: markets,
      accountMembership: accountMembership,
    };

    fullStorage = {
      s: storage,

      updateControllerStateLambdas: MichelsonMap.fromLiteral({}),
    }

    Controller_Instance = await Controller.new(fullStorage);
    await revertDefaultSigner();
  });

  describe("deploy", async () => {
    it("should check storage after deploy", async () => {
      const cStorage = await Controller_Instance.storage();

      assert.equal(FACTORY, cStorage.factory);
      assert.equal(ADMIN, cStorage.admin);
      assert.deepEqual(qTokens, cStorage.qTokens);
      assert.equal(accBorrows.get({ user: USER, token: ZERO_ADDRESS}), await cStorage.accountBorrows.get({ user: USER, token: ZERO_ADDRESS}));
      assert.equal(accTokens.get({ user: USER, token: ZERO_ADDRESS}), await cStorage.accountTokens.get({ user: USER, token: ZERO_ADDRESS}));
      const sMarket =  await cStorage.markets.get(qToken);
      const market = markets.get(qToken);
      assert.equal(market.collateralFactor, Fixed(sMarket.collateralFactor));
      assert.equal(market.lastPrice, Fixed(sMarket.lastPrice));
      assert.equal(market.oracle, sMarket.oracle);
      assert.equal(market.exchangeRate, Fixed(sMarket.exchangeRate));
      assert.deepEqual(accountMembership.get(USER), await cStorage.accountMembership.get(USER));
    });
  });

  describe("updatePrice", async () => {
    it("should update price", async () => {
      setSigner(qTokenORACLE);

      const newPrice = 150;

      await Controller_Instance.updatePrice(qToken, newPrice);
      const s = await Controller_Instance.storage();

      assert.equal(newPrice, (await s.markets.get(qToken)).lastPrice)
    });

    it("should get exception, call from NOT ORACLE", async () => {
      await truffleAssert.fails(Controller_Instance.updatePrice(qToken, 0),
          truffleAssert.INVALID_OPCODE, "NorOracle");
    });
  });

  describe("setOracle", async () => {
    it("should set oracle", async () => {
      setSigner(ADMIN);

      const newORACLE = accounts[9];

      await Controller_Instance.setOracle(qToken, newORACLE);
      const s = await Controller_Instance.storage();

      assert.equal(newORACLE, (await s.markets.get(qToken)).oracle)
    });

    it("should get exception, call from NOT ADMIN", async () => {
      const newORACLE = accounts[9];

      await truffleAssert.fails(Controller_Instance.setOracle(qToken, newORACLE),
          truffleAssert.INVALID_OPCODE, "NotAdmin");
    });
  });

  describe("register", async () => {
    it("should register new pair", async () => {
      setSigner(FACTORY);

      const newToken = accounts[8];
      const newQToken = accounts[9];

      await Controller_Instance.register(newToken, newQToken);
      const s = await Controller_Instance.storage();

      assert.ok(s.qTokens.includes(newQToken));
      assert.equal(newQToken, await s.pairs.get(newToken));
    });

    it("should get exception, call from NOT FACTORY", async () => {
      const newToken = accounts[8];
      const newQToken = accounts[9];

      await truffleAssert.fails(Controller_Instance.register(newToken, newQToken),
          truffleAssert.INVALID_OPCODE, "NotFactory");
    });

    it("should get exception qToken contains in storage qTokens", async () => {
      setSigner(FACTORY);

      const newToken = accounts[8];
      const newQToken = qTokens[0];

      await truffleAssert.fails(Controller_Instance.register(newToken, newQToken),
          truffleAssert.INVALID_OPCODE, "Contains");
    });
  });

  describe("UpdateQToken", async () => {
    it("should update qToken", async () => {
      setSigner(qToken); // contains in storage qTokens

      const newExchRate = 131517;
      const newTokens = 111315;
      const newBorrows = 181216;

      await Controller_Instance.updateQToken(USER, newTokens, newBorrows, newExchRate);
      const s = await Controller_Instance.storage();

      assert.equal(newExchRate, (await s.markets.get(qToken)).exchangeRate);
      assert.equal(newTokens, await s.accountTokens.get({user: USER, token: qToken}));
      assert.equal(newBorrows, await s.accountBorrows.get({user: USER, token: qToken}));
    });

    it("should get exception, call from NOT contains token", async () => {
      await truffleAssert.fails(Controller_Instance.updateQToken(USER, 0, 0, 0),
          truffleAssert.INVALID_OPCODE, "NotContains");
    });
  });

  describe("enterMarket", async () => {
    it("should enter market", async () => {
      const newUSER = accounts[9];
      setSigner(newUSER);

      await Controller_Instance.enterMarket(qToken);
      const s = await Controller_Instance.storage();

      assert.equal(qToken, await s.accountMembership.get(newUSER));
    });

    it("should get exception, user already enter this token", async () => {
      setSigner(USER); // user has qToken via deploy
      await truffleAssert.fails(Controller_Instance.enterMarket(qToken),
          truffleAssert.INVALID_OPCODE, "AlreadyEnter");
    });
    it("should get exception, try to enter with fifth qToken", async () => {
      const newUSER = accounts[9];
      const tokens = [accounts[0], accounts[1], accounts[2], accounts[3]];

      setSigner(FACTORY);
      for(let i = 0; i < tokens.length; ++i) {
        await Controller_Instance.register(tokens[i], tokens[i]);
      }

      setSigner(newUSER);
      for(let i = 0; i < tokens.length; ++i) {
        await Controller_Instance.enterMarket(tokens[i]);
      }

      await truffleAssert.fails(Controller_Instance.enterMarket(qToken), //qToken is accounts[5]
          truffleAssert.INVALID_OPCODE, "LimitExceeded");
    });
  });

  describe.only("exitMarket", async () => {
    beforeEach("setup", async () => {
      setSigner(FACTORY);
    });
    it("should exit from market", async () => {
      function getLigo(isDockerizedLigo) {
        let path = "ligo";
        if (isDockerizedLigo) {
          path = "docker run -v $PWD:$PWD --rm -i ligolang/ligo:next";
          try {
            execSync(`${path}  --help`);
          } catch (err) {
            path = "ligo";
            execSync(`${path}  --help`);
          }
        } else {
          try {
            execSync(`${path}  --help`);
          } catch (err) {
            path = "docker run -v $PWD:$PWD --rm -i ligolang/ligo:next";
            execSync(`${path}  --help`);
          }
        }
        return path;
      }
      let ligo = getLigo(false);
      console.log("HERE1")

      const stdOut = execSync(`${ligo} compile-parameter --michelson-format=json contracts/Controller.ligo main 'SetUpdateControllerStateLambdas(UpdateControllerState)'`,
                     { maxBuffer: 1024 * 500 });

      console.log("HERE2")


      setSigner(FACTORY)
      await Controller_Instance.register(DAI_Instance.address, DAI_Instance.address)

      const newUSER = accounts[9];
      setSigner(newUSER);
      await Controller_Instance.enterMarket(DAI_Instance.address);

      await Controller_Instance.setUpdateControllerStateLambdas(DAI_Instance.updateControllerState);

      await Controller_Instance.exitMarket(DAI_Instance.address);
      const s = await Controller_Instance.storage();


    });

    // it("should get exception, call from NOT contains token", async () => {
    //   await truffleAssert.fails(Controller_Instance.updateQToken(USER, 0, 0, 0),
    //       truffleAssert.INVALID_OPCODE, "NotContains");
    // });
  });
});
