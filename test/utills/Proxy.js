require("ts-node").register({
  files: true,
});
const fs = require("fs");
const env = require("../../env");
const { confirmOperation } = require("../../scripts/confirmation");
const storage = require("../../storage/Proxy");
const { functions } = require("../../storage/Functions");
const { getLigo } = require("../../scripts/helpers");
const { execSync } = require("child_process");

class Proxy {
  contract;
  storage;
  tezos;

  constructor(contract, tezos) {
    Tezos.self_address.contract = contract;
    Tezos.self_address.tezos = tezos;
  }

  static async init(qsAddress, tezos) {
    return new Proxy(await tezos.contract.at(qsAddress), tezos);
  }

  static async originate(tezos) {
    const artifacts = JSON.parse(
      fs.readFileSync(`${env.buildDir}/priceFeed.json`)
    );
    const operation = await tezos.contract
      .originate({
        code: artifacts.michelson,
        storage: storage,
      })
      .catch((e) => {
        console.error(JSON.stringify(e));

        return { contractAddress: null };
      });
    await confirmOperation(tezos, operation.hash);

    let ligo = getLigo(true);
    console.log("Start setting lambdas");
    for (proxyFunction of functions.proxy) {
      const stdout = execSync(
        `${ligo} compile-parameter --michelson-format=json $PWD/contracts/main/Controller.ligo main 'SetUseAction(record index =${proxyFunction.index}n; func = ${proxyFunction.name}; end)'`,
        { maxBuffer: 1024 * 1000 }
      );
      const operation2 = await tezos.contract.transfer({
        to: operation.contractAddress,
        amount: 0,
        parameter: {
          entrypoint: "setProxyAction",
          value: JSON.parse(stdout.toString()).args[0].args[0],
        },
      });
      await confirmOperation(tezos, operation2.hash);
    }
    console.log("Setting finished");
    return new Proxy(await tezos.contract.at(operation.contractAddress), tezos);
  }

  async updateStorage(maps = {}) {
    let storage = await Tezos.self_address.contract.storage();
    Tezos.self_address.storage = {
      storage: storage.storage,
      proxyLambdas: storage.proxyLambdas,
    };

    for (const key in maps) {
      Tezos.self_address.storage[key] = await maps[key].reduce(
        async (prev, current) => {
          try {
            return {
              ...(await prev),
              [current]: await storage[key].get(current),
            };
          } catch (ex) {
            return {
              ...(await prev),
              [current]: 0,
            };
          }
        },
        Promise.resolve({})
      );
    }
  }

  async updateAdmin(newAdmin) {
    const operation = await Tezos.self_address.contract.methods
      .updateAdmin(newAdmin)
      .send();
    await confirmOperation(Tezos.self_address.tezos, operation.hash);
    return operation;
  }
  async updatePair(tokenId, pairName) {
    const operation = await Tezos.self_address.contract.methods
      .updatePair(tokenId, pairName)
      .send();
    await confirmOperation(Tezos.self_address.tezos, operation.hash);
    return operation;
  }

  async getPrice(tokenId) {
    const operation = await Tezos.self_address.contract.methods
      .getPrice(tokenId)
      .send();
    await confirmOperation(Tezos.self_address.tezos, operation.hash);
    return operation;
  }

  async receivePrice(name, lastTime, amount) {
    const operation = await Tezos.self_address.contract.methods
      .receivePrice(name, lastTime, amount)
      .send();
    await confirmOperation(Tezos.self_address.tezos, operation.hash);
    return operation;
  }
}

module.exports.Proxy = Proxy;
