const { alice } = require("../../scripts/sandbox/accounts");

const { InMemorySigner } = require("@taquito/signer");
const { TezosToolkit } = require("@taquito/taquito");

module.exports = {
  revertDefaultSigner: async function () {
    tezos = new TezosToolkit(tezos.rpc.url);
    tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(alice.pkh));
  },

  setSigner: async function (signer) {
    tezos = new TezosToolkit(tezos.rpc.url);
    tezos.setSignerProvider(await new InMemorySigner.fromSecretKey(signer));
  },
};
