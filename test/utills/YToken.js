require("ts-node").register({
  files: true,
});
const fs = require("fs");
const env = require("../../env");
const { confirmOperation } = require("../../scripts/confirmation");
const storage = require("../../storage/YToken");
const { functions } = require("../../storage/Functions");
const { getLigo } = require("../../scripts/helpers");
const { execSync } = require("child_process");

class YToken {
  contract;
  storage;
  tezos;

  constructor(contract, tezos) {
    this.contract = contract;
    this.tezos = tezos;
  }

  static async init(qsAddress, tezos) {
    return new YToken(await tezos.contract.at(qsAddress), tezos);
  }

  static async originate(tezos) {
    const artifacts = JSON.parse(
      fs.readFileSync(`${env.buildDir}/yToken.json`)
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
    console.log("Start setting Token lambdas");
    let yTokenFunction = 0;
    for (yTokenFunction of functions.token) {
      const stdout = execSync(
        `${ligo} compile-parameter --michelson-format=json $PWD/contracts/main/yToken.ligo main 'SetTokenAction(record index =${yTokenFunction.index}n; func = ${yTokenFunction.name}; end)'`,
        { maxBuffer: 1024 * 1000 }
      );
      const operation2 = await tezos.contract.transfer({
        to: operation.contractAddress,
        amount: 0,
        parameter: {
          entrypoint: "setTokenAction",
          value: JSON.parse(stdout.toString()).args[0].args[0].args[0].args[0]
            .args[0],
        },
      });
      await confirmOperation(tezos, operation2.hash);
    }
    console.log("Start setting yToken lambdas");
    yTokenFunction = 0;
    for (yTokenFunction of functions.yToken) {
      const stdout = execSync(
        `${ligo} compile-parameter --michelson-format=json $PWD/contracts/main/yToken.ligo main 'SetUseAction(record index =${yTokenFunction.index}n; func = ${yTokenFunction.name}; end)'`,
        { maxBuffer: 1024 * 1000 }
      );
      const operation3 = await tezos.contract.transfer({
        to: operation.contractAddress,
        amount: 0,
        parameter: {
          entrypoint: "setUseAction",
          value: JSON.parse(stdout.toString()).args[0].args[0].args[0].args[0]
            .args[0],
        },
      });
      await confirmOperation(tezos, operation3.hash);
    }
    console.log("Setting finished");
    return new YToken(
      await tezos.contract.at(operation.contractAddress),
      tezos
    );
  }

  async updateStorage(maps = {}) {
    let storage = await this.contract.storage();
    this.storage = {
      storage: storage.storage,
      YTokenLambdas: storage.YTokenLambdas,
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

  async transfer(txs) {
    const operation = await this.contract.methods.transfer(txs).send();
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

  async balanceOf(requests, callback) {
    const operation = await this.contract.methods
      .balanceOf(requests, callback)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async getTotalSupply(token_id, receiver) {
    const operation = await this.contract.methods
      .getTotalSupply(token_id, receiver)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async updateInterest(token_id) {
    const operation = await this.contract.methods
      .updateInterest(token_id)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async setAdmin(newAdmin) {
    const operation = await this.contract.methods.setAdmin(newAdmin).send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async withdrawReserve(token_id, amount) {
    const operation = await this.contract.methods
      .withdrawReserve(token_id, amount)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async addMarket(
    interstRateModel,
    assetAddress,
    collateralFactor,
    reserveFactor,
    maxBorrowRate,
    tokenMetadata,
    faType,
    type
  ) {
    const operation = await this.contract.methods
      .addMarket(
        interstRateModel,
        assetAddress,
        collateralFactor,
        reserveFactor,
        maxBorrowRate,
        tokenMetadata,
        faType,
        type
      )
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async setTokenFactors(
    tokenId,
    collateralFactor,
    reserveFactor,
    interstRateModel,
    maxBorrowRate
  ) {
    const operation = await this.contract.methods
      .setTokenFactors(
        tokenId,
        collateralFactor,
        reserveFactor,
        interstRateModel,
        maxBorrowRate
      )
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async setGlobalFactors(closeFactor, liqIncentive, priceFeedProxy) {
    const operation = await this.contract.methods
      .setGlobalFactors(closeFactor, liqIncentive, priceFeedProxy)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async mint(token_id, amount) {
    const operation = await this.contract.methods.mint(token_id, amount).send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async redeem(token_id, amount) {
    const operation = await this.contract.methods
      .redeem(token_id, amount)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async borrow(token_id, amount) {
    const operation = await this.contract.methods
      .borrow(token_id, amount)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async repay(token_id, amount) {
    const operation = await this.contract.methods
      .repay(token_id, amount)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async liquidate(borrowToken, collateralToken, borrower, amount) {
    const operation = await this.contract.methods
      .liquidate(borrowToken, collateralToken, borrower, amount)
      .send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async enterMarket(token_id) {
    const operation = await this.contract.methods.enterMarket(token_id).send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async exitMarket(token_id) {
    const operation = await this.contract.methods.exitMarket(token_id).send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }

  async updatePrice(tokenSet) {
    const operation = await this.contract.methods.updatePrice(tokenSet).send();
    await confirmOperation(this.tezos, operation.hash);
    return operation;
  }
}

module.exports.YToken = YToken;
