const fs = require("fs");
const env = require("../../env");
const { confirmOperation } = require("../../scripts/confirmation");
const storage = require("../../storage/SendRate");

class SendRate {
  contract;
  storage;
  tezos;

  constructor(contract, tezos) {
    this.contract = contract;
    this.tezos = tezos;
  }

  static async init(qsAddress, tezos) {
    return new SendRate(await tezos.contract.at(qsAddress), tezos);
  }

  static async originate(tezos) {
    const artifacts = JSON.parse(
      fs.readFileSync(`${env.buildDir}/getInterests.json`)
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
    return new SendRate(
      await tezos.contract.at(operation.contractAddress),
      tezos
    );
  }

  async updateStorage(maps = {}) {
    let storage = await this.contract.storage();
    this.storage = {
      utilRate: storage.utilRate,
      borrowRate: storage.borrowRate,
      supplyRate: storage.supplyRate,
      interestAddress: storage.interestAddress,
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

  async setInterestRate(newAddress) {
    const operation = await this.contract.methods
      .setInterestRate(newAddress)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async sendUtil(tokenId, borrows, cash, reserves) {
    const operation = await this.contract.methods
      .sendUtil(tokenId, borrows, cash, reserves)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async sendBorrow(tokenId, borrows, cash, reserves) {
    const operation = await this.contract.methods
      .sendBorrow(tokenId, borrows, cash, reserves)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async sendSupply(tokenId, borrows, cash, reserves) {
    const operation = await this.contract.methods
      .sendSupply(tokenId, borrows, cash, reserves)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }
}

module.exports.SendRate = SendRate;
