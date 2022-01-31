const fs = require("fs");
const env = require("../../env");
const { confirmOperation } = require("../../scripts/confirmation");
let storage = require("../../storage/getOracle");

class GetOracle {
  contract;
  storage;
  tezos;

  constructor(contract, tezos) {
    this.contract = contract;
    this.tezos = tezos;
  }

  static async originate(tezos) {
    const Normalizer = fs.readFileSync("./contracts/test/Normalizer.tz").toString();

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
      oracleContract: storage.oracleContract,
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

  async update(map) {
    const operation = await this.contract.methods.update(map).send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  // async updPrice(str, price) {
  //   storage.assetMap.get(str).computedPrice = price;
  //   console.log(storage.assetMap.get("KNC-USD").computedPrice);
  // }

  // async updOracle(map) {
  //   const operation = await this.contract.methods
  //     .update(map)
  //     .send();
  //   await confirmOperation(this.tezos, operation.hash);
  //   return operation;
  // }
  // async updParamsOracle(name, price, time) {
  //   const operation = await this.contract.methods
  //     .updParamsOracle(name, price, time)
  //     .send();
  //   await confirmOperation(this.tezos, operation.hash);
  //   return operation;
  // }

  // async updReturnAddressOracle(addr) {
  //   const operation = await this.contract.methods
  //     .updReturnAddressOracle(addr)
  //     .send();
  //   await confirmOperation(this.tezos, operation.hash);
  //   return operation;
  // }
}

module.exports.GetOracle = GetOracle;
