const fs = require("fs");
const env = require("../../env");
const { confirmOperation } = require("../../scripts/confirmation");
const storage = require("../../storage/interestRate");
const { functions } = require("../../storage/functions");
const { getLigo } = require("../../scripts/helpers");
const { execSync } = require("child_process");

class InterestRate {
  contract;
  storage;
  tezos;

  constructor(contract, tezos) {
    this.contract = contract;
    this.tezos = tezos;
  }

  static async init(qsAddress, tezos) {
    return new InterestRate(await tezos.contract.at(qsAddress), tezos);
  }

  static async originate(tezos) {
    const artifacts = JSON.parse(
      fs.readFileSync(`${env.buildDir}/interestRate.json`)
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

    return new InterestRate(
      await tezos.contract.at(operation.contractAddress),
      tezos
    );
  }

  async updateStorage(maps = {}) {
    let storage = await this.contract.storage();
    this.storage = {
      admin: storage.admin,
      yToken: storage.yToken,
      kinkF: storage.kinkF,
      baseRateF: storage.baseRateF,
      multiplierF: storage.multiplierF,
      jumpMultiplierF: storage.jumpMultiplierF,
      reserveFactorF: storage.reserveFactorF,
      lastUpdTime: storage.lastUpdTime,
      utilLambda: storage.utilLambda,
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
    const operation = await this.contract.methods.updateAdmin(newAdmin).send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async setCoefficients(kinkF, baseRateF, multiplierF, jumpMultiplierF) {
    const operation = await this.contract.methods
      .setCoefficients(kinkF, baseRateF, multiplierF, jumpMultiplierF)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }
}

module.exports.InterestRate = InterestRate;
