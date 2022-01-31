const { dev } = require("../scripts/sandbox/accounts");
const { confirmOperation } = require("../scripts/confirmation");
const { InMemorySigner } = require("@taquito/signer");
const { TezosToolkit } = require("@taquito/taquito");

module.exports = async (tezos) => {
  return;
  const tezos = new TezosToolkit("https://hangzhounet.api.tez.ie/");

  tezos.setProvider({
    config: {
      confirmationPollingTimeoutSecond: 500000,
    },
    signer: await InMemorySigner.fromSecretKey(dev.sk),
  });

  let priceFeedContract = await tezos.contract.at(
    "KT1WvRRn1SZc26aLZHZvYmj6ogELyVbCYDqG"
  );
  let yTokenContract = await tezos.contract.at(
    "KT1LTqpmGJ11EebMVWAzJ7DWd9msgExvHM94"
  );

  const batchArray = [
    {
      kind: "transaction",
      ...yTokenContract.methods.updateInterest(1).toTransferParams(),
    },
    {
      kind: "transaction",
      ...priceFeedContract.methods.getPrice([1]).toTransferParams(),
    },
    {
      kind: "transaction",
      ...yTokenContract.methods.updateInterest(0).toTransferParams(),
    },
    {
      kind: "transaction",
      ...priceFeedContract.methods.getPrice([0]).toTransferParams(),
    },
    {
      kind: "transaction",
      ...yTokenContract.methods
        .setTokenFactors(
          1,
          700000000000000000,
          150000000000000000,
          "KT1Wk3PGiFtj2nLf6BWLBUUYFR8Z6WUWAbTp",
          5000000000000,
          700000000000000000
        )
        .toTransferParams(),
    },
    {
      kind: "transaction",
      ...yTokenContract.methods
        .setTokenFactors(
          0,
          800000000000000000,
          150000000000000000,
          "KT1UoF8AA6M2ReAzZqt9WPeTvXm1WWEDnG7s",
          5000000000000,
          800000000000000000
        )
        .toTransferParams(),
    },
  ];

  const batch = await tezos.wallet.batch(batchArray);
  const operation = await batch.send();
  await confirmOperation(tezos, operation.opHash);
  console.log("Done");
};
