const { migrate } = require("../scripts/helpers");
const { dev } = require("../scripts/sandbox/accounts");
const { MichelsonMap } = require("@taquito/michelson-encoder");
const { confirmOperation } = require("../scripts/confirmation");
const { InMemorySigner } = require("@taquito/signer");

const metadata = MichelsonMap.fromLiteral({
  "": Buffer.from("tezos-storage:tbtc", "ascii").toString("hex"),
  tbtc: Buffer.from(
    JSON.stringify({
      name: "TBTC",
      version: "v1.0.0",
      description: "TBTC test token.",
    }),
    "ascii"
  ).toString("hex"),
});

const tokenMetadata = MichelsonMap.fromLiteral({
  symbol: Buffer.from("TBTC").toString("hex"),
  name: Buffer.from("TBTCtoken").toString("hex"),
  decimals: Buffer.from("8").toString("hex"),
  is_transferable: Buffer.from("true").toString("hex"),
  is_boolean_amount: Buffer.from("false").toString("hex"),
  should_prefer_symbol: Buffer.from("false").toString("hex"),
  thumbnailUri: Buffer.from("ipfs://QmQxmFng1X5KhLHEgNKZh5f2Da146jBC5tjw3sYnyfd2yS").toString("hex"),
});

module.exports = async (tezos) => {
  const contractAddress = await migrate(tezos, "fa2", {
    totalSupplyF: "0",
    ledger: MichelsonMap.fromLiteral({}),
    account_info: MichelsonMap.fromLiteral({}),
    token_info: MichelsonMap.fromLiteral({}),
    metadata: metadata,
    token_metadata: MichelsonMap.fromLiteral({}),
    minters: [],
    admin: dev.pkh,
    pending_admin: dev.pkh,
    last_token_id: "0",
  });

  console.log(`Fa2 contract: ${contractAddress}`);

  tezos.setProvider({
    signer: await InMemorySigner.fromSecretKey(dev.sk),
  });
  let contract = await tezos.contract.at(contractAddress);
  let op = await contract.methods.create_token(tokenMetadata).send();
  await confirmOperation(tezos, op.hash);
};
