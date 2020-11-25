const { accounts } = require("../../scripts/sandbox/accounts");
const { accountsMap } = require("../../scripts/sandbox/accounts");
const { InMemorySigner } = require("@taquito/signer");

module.exports = {
  revertDefaultSigner: async function () {
    tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(accounts[0])));
  },

  setSigner: async function (signer) {
    tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(accountsMap.get(signer)));
  }
}
