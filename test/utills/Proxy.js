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
    this.contract = contract;
    this.tezos = tezos;
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

    return new Proxy(await tezos.contract.at(operation.contractAddress), tezos);
  }

  async updateStorage(maps = {}) {
    let storage = await this.contract.storage();
    this.storage = {
      admin: storage.admin,
      oracle: storage.oracle,
      yToken: storage.yToken,
      pairName: storage.pairName,
      pairId: storage.pairId,
    };

    for (const key in maps) {
      this.storage[key] = await maps[key].reduce(async (prev, current) => {
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
      }, Promise.resolve({}));
    }
  }

  async updateAdmin(newAdmin) {
    const operation = await this.contract.methods.setProxyAdmin(newAdmin).send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async updateOracle(newOracle) {
    const operation = await this.contract.methods
      .updateOracle(newOracle)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async updateYToken(newYToken) {
    const operation = await this.contract.methods
      .updateYToken(newYToken)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async updatePair(tokenId, pairName) {
    const operation = await this.contract.methods
      .updatePair(tokenId, pairName)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async getPrice(tokenSet) {
    const operation = await this.contract.methods.getPrice(tokenSet).send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async receivePrice(name, lastTime, amount) {
    const operation = await this.contract.methods
      .receivePrice(name, lastTime, amount)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }
}

module.exports.Proxy = Proxy;
