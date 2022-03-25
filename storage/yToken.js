const { MichelsonMap } = require("@taquito/michelson-encoder");
const { alice } = require("../scripts/sandbox/accounts");
const yTokenErrors = require("./yTokenTZIP16Errors");

const metadata = MichelsonMap.fromLiteral({
  "": Buffer.from("tezos-storage:yupana", "ascii").toString("hex"),
  yupana: Buffer.from(
    JSON.stringify({
      name: "Yupana",
      version: "v1.0.0",
      description: "Yupana protocol.",
      authors: ["Madfish.Solutions <https://www.madfish.solutions>"],
      source: {
        tools: ["Ligo", "Flextesa"],
        location: "https://ligolang.org/",
      },
      homepage: "https://yupana.com",
      interfaces: ["TZIP-12-1728fcfe", "TZIP-16"],
      errors: yTokenErrors,
      views: [],
    }),
    "ascii"
  ).toString("hex"),
});

const yStorage = {
  admin: alice.pkh,
  admin_candidate: null,
  ledger: MichelsonMap.fromLiteral({}),
  accounts: MichelsonMap.fromLiteral({}),
  tokens: MichelsonMap.fromLiteral({}),
  lastTokenId: "0",
  priceFeedProxy: alice.pkh,
  closeFactorF: "0",
  liqIncentiveF: "0",
  maxMarkets: "0",
  markets: MichelsonMap.fromLiteral({}),
  borrows: MichelsonMap.fromLiteral({}),
  assets: MichelsonMap.fromLiteral({}),
};

module.exports = {
  storage: yStorage,
  metadata: metadata,
  token_metadata: MichelsonMap.fromLiteral({}),
  tokenLambdas: MichelsonMap.fromLiteral({}),
  useLambdas: MichelsonMap.fromLiteral({}),
};
