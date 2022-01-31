const { migrate } = require("../scripts/helpers");
const { MichelsonMap } = require("@taquito/michelson-encoder");

const metadata = MichelsonMap.fromLiteral({
  "": Buffer.from("tezos-storage:txtz", "ascii").toString("hex"),
  txtz: Buffer.from(
    JSON.stringify({
      name: "TXTZ",
      version: "v1.0.0",
      description: "TXTZ test token.",
    }),
    "ascii"
  ).toString("hex"),
});

const tokenMetadata = MichelsonMap.fromLiteral({
  0: {
    token_id: "0",
    token_info: MichelsonMap.fromLiteral({
      symbol: Buffer.from("TXTZ").toString("hex"),
      name: Buffer.from("TXTZtoken").toString("hex"),
      decimals: Buffer.from("6").toString("hex"),
      is_transferable: Buffer.from("true").toString("hex"),
      is_boolean_amount: Buffer.from("false").toString("hex"),
      should_prefer_symbol: Buffer.from("false").toString("hex"),
      thumbnailUri: Buffer.from("ipfs://QmRjdJtosqYqHaC8PXUYLZEe2PRi42cTwoVbn1gGj2NoM9").toString("hex"),
    }),
  },
});

module.exports = async (tezos) => {
  return;
  const contractAddress = await migrate(tezos, "fa12", {
    totalSupplyF: "0",
    ledger: MichelsonMap.fromLiteral({}),
    metadata: metadata,
    token_metadata: tokenMetadata,
  });

  console.log(`Fa12 contract: ${contractAddress}`);
};
