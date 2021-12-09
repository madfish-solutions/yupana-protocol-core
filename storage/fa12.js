const { MichelsonMap } = require("@taquito/michelson-encoder");

const metadata = MichelsonMap.fromLiteral({
  "": Buffer.from("tezos-storage:txtz", "ascii").toString("hex"),
  txtz: Buffer.from(
    JSON.stringify({
      name: "TXZT",
      version: "v1.0.0",
      description: "TXZT test token.",
    }),
    "ascii"
  ).toString("hex"),
});

const tokenMetadata = MichelsonMap.fromLiteral({
  0: {
    token_id: "0",
    token_info: MichelsonMap.fromLiteral({
      symbol: Buffer.from("TXZT").toString("hex"),
      name: Buffer.from("TXZTtoken").toString("hex"),
      decimals: Buffer.from("6").toString("hex"),
      is_transferable: Buffer.from("true").toString("hex"),
      is_boolean_amount: Buffer.from("false").toString("hex"),
      should_prefer_symbol: Buffer.from("false").toString("hex"),
    }),
  },
});

module.exports = {
  totalSupplyF: "0",
  ledger: MichelsonMap.fromLiteral({}),
  metadata: metadata,
  token_metadata: tokenMetadata,
};
