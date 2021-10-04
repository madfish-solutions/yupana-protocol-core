const fs = require("fs");
const env = require("../../env");
const { confirmOperation } = require("../../scripts/confirmation");
const storage = require("../../storage/GetOracle");
// const contract = require("../../KT1MwuujtBodVQFm1Jk1KTGNc49wygqoLvpe.tz");

class GetOracle {
  contract;
  storage;
  tezos;

  constructor(contract, tezos) {
    this.contract = contract;
    this.tezos = tezos;
  }

  static async init(qsAddress, tezos) {
    return new GetOracle(await tezos.contract.at(qsAddress), tezos);
  }


  static async originate(tezos) {
    const Normalizer = fs.readFileSync("Norma.tz").toString();

    // const artifacts = JSON.parse(
    //   fs.readFileSync(contract)
    // );
    const operation = await tezos.contract
      .originate({
        code: Normalizer,
        storage: storage,
      })
      .catch((e) => {
        console.error(JSON.stringify(e));

        return { contractAddress: null };
      });
    await confirmOperation(tezos, operation.hash);
    return new GetOracle(
      await tezos.contract.at(operation.contractAddress),
      tezos
    );
  }

  async updateStorage(maps = {}) {
    let storage = await this.contract.storage();
    this.storage = {
      assetCodes: storage.assetCodes,
      assetMap: storage.assetMap,
      numDataPoints: storage.numDataPoints,
      oracleContract: storage.oracleContract
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

  async updOracle(map) {
    const operation = await this.contract.methods
      .update(map)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }
}

module.exports.GetOracle = GetOracle;
