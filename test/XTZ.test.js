const { MichelsonMap } = require('@taquito/michelson-encoder');
const { accounts } = require('../scripts/sandbox/accounts');
const XTZ = artifacts.require('XTZ');

contract('XTZ', async () => {

  const DEFAULT = accounts[0];
  const SENDER = accounts[1];

  const defaultsBalance = '1500';
  const defaultsAmt = '15';

  const totalSupply = '50000';

  let XTZ_Instancce;
  let storage;

  before('setup', async () => {
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
    }

    XTZ_Instancce = await XTZ.new(storage);
  });

  describe('deploy', async () => {
    it('should check storage after deploy', async () => {
      const xtzStorage = await XTZ_Instancce.storage();
      const ledger = await (xtzStorage.ledger).get(DEFAULT);
      const amt = await ledger.allowances.get(DEFAULT);

      assert.equal(totalSupply, xtzStorage.totalSupply);
      assert.equal(defaultsBalance, ledger.balance);
      assert.equal(defaultsAmt, amt)
    });
  });

  describe('mint', async () => {
    it('should send value and check storage', async() => {
      await XTZ_Instancce.mint(100);
      //
      // const op = tezos.contract.transfer(
      //     {
      //       to: XTZ_Instancce.address,
      //       amount: 100,
      //       parameter: {
      //         entrypoint: 'mint'
      //       }
      //     }
      // )
      // await (await op).confirmation();

      const balance = await ((await XTZ_Instancce.storage()).ledger).get(DEFAULT);
      console.log(balance);


      assert.equal(1, 1);
    });
  })
});
