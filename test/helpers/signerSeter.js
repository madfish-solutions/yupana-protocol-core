const { accounts } = require("../../scripts/sandbox/accounts");
const { accountsMap } = require("../../scripts/sandbox/accounts");
const { InMemorySigner } = require("@taquito/signer");
const { TezosToolkit } = require("@taquito/taquito");

module.exports = {
  revertDefaultSigner: async function () {
    tezos = new TezosToolkit(tezos.rpc.url);
    tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])));
  },

  setSigner: async function (signer) {
    tezos = new TezosToolkit(tezos.rpc.url);
    tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(signer)));
  }
}
