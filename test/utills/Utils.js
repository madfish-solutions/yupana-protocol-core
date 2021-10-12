require("dotenv").config();

const { TezosToolkit } = require("@taquito/taquito");
const { InMemorySigner } = require("@taquito/signer");
const { alice } = require("../../scripts/sandbox/accounts");
const { confirmOperation } = require("../../scripts/confirmation");
const env = require("../../env");
const defaultNetwork = "development";
const network = env.network || defaultNetwork;

class Utils {
  static async initTezos() {
    const networkConfig = env.networks[network] || env.networks[defaultNetwork];
    const tezos = new TezosToolkit(networkConfig.rpc);

    tezos.setProvider({
      config: {
        confirmationPollingTimeoutSecond: env.confirmationPollingTimeoutSecond,
      },
      signer: await InMemorySigner.fromSecretKey(alice.sk),
    });

    return tezos;
  }

  static async setProvider(tezos, newProviderSK) {
    tezos.setProvider({
      signer: await InMemorySigner.fromSecretKey(newProviderSK),
    });

    return tezos;
  }

  static async trasferTo(tezos, to, amount) {
    let operation = await tezos.contract.transfer({
      to: to,
      amount: amount,
      mutez: true,
    });
    await confirmOperation(tezos, operation.hash);
  }

  static async bakeBlocks(tezos, count) {
    for (let i = 0; i < count; ++i) {
      const operation = await tezos.contract.transfer({
        to: await tezos.signer.publicKeyHash(),
        amount: 1,
      });

      await confirmOperation(tezos, operation.hash);
    }
  }
}

module.exports.Utils = Utils;
