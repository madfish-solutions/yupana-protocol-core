const { MichelsonMap } = require("@taquito/michelson-encoder");
const { InMemorySigner } = require("@taquito/signer");

const { accounts } = require("../scripts/sandbox/accounts");
const { accountsMap } = require("../scripts/sandbox/accounts");

const XTZ = artifacts.require("XTZ");

contract("XTZ", async () => {
  const DEFAULT = accounts[0];
  const SENDER = accounts[1];

  const defaultsBalance = 1500;
  const defaultsAmt = 15;

  const totalSupply = 50000;
  const decimal = 1e+6;

  let XTZ_Instancce;
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

    XTZ_Instancce = await XTZ.new(storage);
  });

  describe("deploy", async () => {
    it("should check storage after deploy", async () => {
      const xtzStorage = await XTZ_Instancce.storage();
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
      const balanceBeforeMintS = (await (await XTZ_Instancce.storage()).ledger.get(DEFAULT)).balance;

      await XTZ_Instancce.mint(null, {amount: amount});

      const balanceAfterMintS = (await (await XTZ_Instancce.storage()).ledger.get(DEFAULT)).balance;

      assert.equal(balanceBeforeMintS.plus(amount * decimal).toString(),
                   balanceAfterMintS.toString());
    });
    it("should receive value from sender, who is not yet in storage", async () => {
      const amount = 5;

      tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(SENDER)));

      await XTZ_Instancce.mint(null, {amount: amount});

      const balanceAfterMintS = (await (await XTZ_Instancce.storage()).ledger.get(SENDER)).balance;

      assert.equal(amount * decimal, balanceAfterMintS);
    });
  });
});
