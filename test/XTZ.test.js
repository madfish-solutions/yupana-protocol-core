const { MichelsonMap } = require("@taquito/michelson-encoder");

const { InMemorySigner } = require("@taquito/signer");

const { networks } = require("../truffle-config");
const { TezosToolkit } = require("@taquito/taquito");
const Tezos = new TezosToolkit(networks.development.host + ":" + networks.development.port);

const { accounts } = require("../scripts/sandbox/accounts");

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
      const balanceBeforeMint = await Tezos.tz.getBalance(SENDER);

      let config = {
        signer: await InMemorySigner.fromSecretKey('edsk3RFfvaFaxbHx8BMtEW1rKQcPtDML3LXjNqMNLCzC3wLC1bWbAt'),
      };
      let config2 = {
        signer: 'edsk3RFfvaFaxbHx8BMtEW1rKQcPtDML3LXjNqMNLCzC3wLC1bWbAt'
      }
      Tezos.setProvider(config);
      Tezos.setSignerProvider(config)
      Tezos.setSignerProvider('edsk3RFfvaFaxbHx8BMtEW1rKQcPtDML3LXjNqMNLCzC3wLC1bWbAt')
      Tezos.setSignerProvider(config2)
      await Tezos.setSignerProvider(config2)
      Tezos.setSignerProvider(await new InMemorySigner.fromSecretKey('edsk3RFfvaFaxbHx8BMtEW1rKQcPtDML3LXjNqMNLCzC3wLC1bWbAt'));
      await Tezos.setSignerProvider(await new InMemorySigner.fromSecretKey('edsk3RFfvaFaxbHx8BMtEW1rKQcPtDML3LXjNqMNLCzC3wLC1bWbAt'));

      const tx = await XTZ_Instancce.mint(null, {amount: amount});
      const balanceAfterMint = await Tezos.tz.getBalance(SENDER);

      console.log('PK', await tezos.signer.publicKeyHash())

      console.log('balance', balanceBeforeMint.toString());
      console.log('after', balanceAfterMint.toString());
      console.log('FROOOM', tx.receipt.source);

      //const balanceAfterMintS = (await (await XTZ_Instancce.storage()).ledger.get(DEFAULT)).balance;
    });
  });
});
