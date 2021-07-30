const { MichelsonMap } = require("@taquito/michelson-encoder");
const truffleAssert = require("truffle-assertions");

const { accounts } = require("../scripts/sandbox/accounts");
const { revertDefaultSigner } = require("./helpers/signerSeter");
const { setSigner } = require("./helpers/signerSeter");

const XTZ = artifacts.require("XTZ");

contract("XTZ", async () => {
  const DEFAULT = accounts[0];
  const SENDER = accounts[1];

  const defaultsBalance = 1500;
  const defaultsAmt = 15;

  const totalSupply = 50000;
  const decimal = 1e6;

  let XTZ_Instance;
  let storage;

  beforeEach("setup", async () => {
    storage = {
      ledger: MichelsonMap.fromLiteral({
        [DEFAULT]: {
          balance: defaultsBalance,
          allowances: MichelsonMap.fromLiteral({
            [DEFAULT]: defaultsAmt,
          }),
        },
      }),
      totalSupply: totalSupply,
    };

    XTZ_Instance = await XTZ.new(storage);
    await revertDefaultSigner();
  });

  describe("deploy", async () => {
    it("should check storage after deploy", async () => {
      const xtzStorage = await XTZ_Instance.storage();
      const ledger = await xtzStorage.ledger.get(DEFAULT);
      const amt = await ledger.allowances.get(DEFAULT);

      assert.equal(totalSupply, xtzStorage.totalSupply);
      assert.equal(defaultsBalance, ledger.balance);
      assert.equal(defaultsAmt, amt);
    });
  });

  describe("mint", async () => {
    it("should send value and check storage", async () => {
      const amount = 5;
      const balanceBeforeMintS = (
        await (await XTZ_Instance.storage()).ledger.get(DEFAULT)
      ).balance;

      await XTZ_Instance.mint(null, { amount: amount });
      const balanceAfterMintS = (
        await (await XTZ_Instance.storage()).ledger.get(DEFAULT)
      ).balance;

      assert.equal(
        balanceBeforeMintS.plus(amount * decimal).toString(),
        balanceAfterMintS.toString()
      );
    });
    it("should receive value from sender, who is not yet in storage", async () => {
      const amount = 5;

      await setSigner(SENDER);

      await XTZ_Instance.mint(null, { amount: amount });
      const balanceAfterMintS = (
        await (await XTZ_Instance.storage()).ledger.get(SENDER)
      ).balance;

      assert.equal(amount * decimal, balanceAfterMintS);
    });
  });

  describe("withdraw", async () => {
    beforeEach("setup", async () => {
      await setSigner(SENDER);
    });
    it("should mint and withdraw part of tez and compare balance after withdraw", async () => {
      const amount = 10;
      await XTZ_Instance.mint(null, { amount: amount });
      const balanceAfterMintS = (
        await (await XTZ_Instance.storage()).ledger.get(SENDER)
      ).balance;

      assert.equal(amount * decimal, balanceAfterMintS);

      const amountWithdraw = 1;
      await XTZ_Instance.withdraw(amountWithdraw * decimal, { s: null });
      const balanceAfterWithdrawS = (
        await (await XTZ_Instance.storage()).ledger.get(SENDER)
      ).balance;

      assert.equal((amount - amountWithdraw) * decimal, balanceAfterWithdrawS);
    });
    it("should get exception, not enough balance", async () => {
      const amount = 10;
      await XTZ_Instance.mint(null, { amount: amount });
      const balanceAfterMintS = (
        await (await XTZ_Instance.storage()).ledger.get(SENDER)
      ).balance;

      assert.equal(amount * decimal, balanceAfterMintS);

      const amountWithdraw = amount + 1;
      await truffleAssert.fails(
        XTZ_Instance.withdraw(amountWithdraw * decimal, { s: null }),
        truffleAssert.INVALID_OPCODE,
        "NotEnoughBalance"
      );
    });
  });
});
