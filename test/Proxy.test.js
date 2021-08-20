const { MichelsonMap } = require("@taquito/michelson-encoder");
const { InMemorySigner } = require("@taquito/signer");
const { TezosToolkit } = require("@taquito/taquito");

const { alice, bob, carol } = require("../scripts/sandbox/accounts");

const { strictEqual } = require("assert");

const { Proxy } = require("../test/utills/Proxy");
const { Utils } = require("../test/utills/Utils");

const { migrate } = require("../scripts/helpers");

const env = require("../env");
const { confirmOperation } = require("../scripts/confirmation");


async function getTezosFor(secretKey) {
  const networkConfig = env.networks["development"];
  let tz = new TezosToolkit(networkConfig.rpc);
  tz.setProvider({ signer: new InMemorySigner(secretKey) });
  return tz;
}

describe("Proxy tests", async () => {
  let tezos;
  let proxy;
  let proxyContractAddress;
  let tzAlice, tzBob, tzCarol;

  before("setup Proxy", async () => {
    tzAlice = await getTezosFor(alice.sk);
    tzBob = await getTezosFor(bob.sk);
    tzCarol = await getTezosFor(carol.sk);

    tezos = await Utils.initTezos();
    proxy = await Proxy.originate(tezos);

    proxyContractAddress = proxy.contract.address;

    tezos = await Utils.setProvider(tezos, alice.sk);

    let operation = await tezos.contract.transfer({
      to: carol.pkh,
      amount: 50000000,
      mutez: true,
    });
    await confirmOperation(tezos, operation.hash);
  });

  it("set Proxy admin", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    console.log("@!!@!@!@!@")
    console.log(await proxy.contract.methods);
    await proxy.updateAdmin(bob.pkh);
    await proxy.updateStorage();
    strictEqual(proxy.storage.admin, controllerContractAddress);
  });
});
