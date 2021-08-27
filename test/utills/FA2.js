require("ts-node").register({
  files: true,
});
const fs = require("fs");
const env = require("../../env");
const { confirmOperation } = require("../../scripts/confirmation");
const storage = require("../../storage/FA2");

class FA2 {
  contract;
  storage;
  tezos;

  constructor(contract, tezos) {
    this.contract = contract;
    this.tezos = tezos;
  }

  static async init(qsAddress, tezos) {
    return new FA2(await tezos.contract.at(qsAddress), tezos);
  }

  static async originate(tezos) {
    const artifacts = JSON.parse(
      fs.readFileSync(`${env.buildDir}/FA2.json`)
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
    return new FA2(
      await tezos.contract.at(operation.contractAddress),
      tezos
    );
  }

  async updateStorage(maps = {}) {
    let storage = await this.contract.storage();
    this.storage = {
      account_info: storage.account_info,
      token_info: storage.token_info,
      metadata: storage.metadata,
      token_metadata: storage.token_metadata,
      minters: storage.minters,
      non_transferable: storage.non_transferable,
      tokens_ids: storage.tokens_ids,
      admin: storage.admin,
      pending_admin: storage.pending_admin,
      last_token_id: storage.last_token_id,
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

  async create_token(tokenMetadata) {
    const operation = await this.contract.methods.create_token(tokenMetadata).send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async updateOperators(updateParams) {
    const operation = await this.contract.methods
      .updateOperators(updateParams)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async mint(txs) {
    const operation = await this.contract.methods.mint_asset(txs).send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }
}

module.exports.FA2 = FA2;
