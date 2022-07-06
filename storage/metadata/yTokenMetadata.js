const { MichelsonMap } = require("@taquito/michelson-encoder");
const yTokenErrors = require("./yTokenTZIP16Errors");

const metadata = MichelsonMap.fromLiteral({
  "": Buffer.from("tezos-storage:yupana", "ascii").toString("hex"),
  yupana: Buffer.from(
    JSON.stringify({
      name: "Yupana Finance Lending Protocol",
      version: "v0.3.4",
      description: "Yupana.Finance is an open-source, decentralized, and non-custodial lending protocol on Tezos built to securely lend and borrow digital assets via smart contracts.",
      authors: ["Madfish.Solutions <https://www.madfish.solutions>"],
      source: {
        tools: ["Ligo", "Flextesa"],
        location:
          "https://github.com/madfish-solutions/yupana-protocol-core/blob/v0.3.4/contracts/main/yToken.ligo",
      },
      homepage: "https://yupana.finance",
      interfaces: ["TZIP-012 git 1728fcfe", "TZIP-016"],
      errors: yTokenErrors,
      views: [],
    }),
    "ascii"
  ).toString("hex"),
});

module.exports = metadata;
