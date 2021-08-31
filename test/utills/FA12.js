require("ts-node").register({
  files: true,
});
const fs = require("fs");
const env = require("../../env");
const { confirmOperation } = require("../../scripts/confirmation");
const storage = require("../../storage/FA12");

class FA12 {
  contract;
  storage;
  tezos;

  constructor(contract, tezos) {
    this.contract = contract;
    this.tezos = tezos;
  }

  static async init(qsAddress, tezos) {
    return new FA12(await tezos.contract.at(qsAddress), tezos);
  }

  static async originate(tezos) {
    const artifacts = JSON.parse(fs.readFileSync(`${env.buildDir}/FA12.json`));
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
    return new FA12(await tezos.contract.at(operation.contractAddress), tezos);
  }

  async updateStorage(maps = {}) {
    let storage = await this.contract.storage();
    this.storage = {
      totalSupply: storage.totalSupply,
      ledger: storage.ledger,
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

  async mint(amt) {
    const operation = await this.contract.methods.mint(amt).send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async approve(adrr, amt) {
    const operation = await this.contract.methods.approve(adrr, amt).send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }
}

module.exports.FA12 = FA12;
