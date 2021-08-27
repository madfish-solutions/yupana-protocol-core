const { dev } = require("../scripts/sandbox/accounts");
const { migrate } = require("../scripts/helpers");
const { MichelsonMap } = require("@taquito/michelson-encoder");

const metadata = MichelsonMap.fromLiteral({
  "": Buffer.from("tezos-storage:ypana", "ascii").toString("hex"),
  ypana: Buffer.from(
    JSON.stringify({
      name: "Ypana",
      version: "v1.0.0",
      description: "Ypana protocol.",
      authors: ["madfish.solutions"],
      source: {
        tools: ["Ligo", "Flextesa"],
        location: "https://ligolang.org/",
      },
      homepage:"https://ypana.com",
      interfaces: ["TZIP-12", "TZIP-16"],
      errors: [],
      views: [],
    }),
    "ascii"
  ).toString("hex"),
});

const tokenStorage = {
  admin: dev.pkh,
  accountInfo: MichelsonMap.fromLiteral({}),
  tokenInfo: MichelsonMap.fromLiteral({}),
  metadata: metadata,
  tokenMetadata: MichelsonMap.fromLiteral({}),
  lastTokenId: "0",
  priceFeedProxy: alice.pkh,
  closeFactor: "0",
  liqIncentive: "0",
  maxMarkets: "0",
};

module.exports = async (tezos) => {
  const contractAddress = await migrate(tezos, "yToken", {
    storage: tokenStorage,
    tokenLambdas: MichelsonMap.fromLiteral({}),
    useLambdas: MichelsonMap.fromLiteral({}),
  });

  console.log(`YToken contract: ${contractAddress}`);
};
