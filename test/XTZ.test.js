const { MichelsonMap } = require('@taquito/michelson-encoder');

const XTZ = artifacts.require('XTZ');

contract('XTZ', () => {

  console.log('test')

  let XTZ_Instancce;
  let storage;

  beforeEach(async () => {

    storage = {
      ledger: MichelsonMap.fromLiteral({
        ['tz1WP3xUvTP6vUWLRnexxnjNTYDiZ7QzVdxo']: {
          balance: '1000',
          allowances: MichelsonMap.fromLiteral({
            ['tz1WP3xUvTP6vUWLRnexxnjNTYDiZ7QzVdxo']: '0',
          }),
        },
      }),
      totalSupply: '1000',
    }

    console.log(storage);
    XTZ_Instancce = await XTZ.new(storage);
  });



  it('deploy', async() => {
    console.log('done')
  });
});
