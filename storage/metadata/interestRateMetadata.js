const { MichelsonMap } = require("@taquito/michelson-encoder");
const interestRateErrors = require("./interestRateTZIP16Errors");

const metadata = MichelsonMap.fromLiteral({
  "": Buffer.from("tezos-storage:interest-rate", "ascii").toString("hex"),
  "interest-rate": Buffer.from(
    JSON.stringify({
      name: "Yupana interest rate model helper contract",
      version: "v0.3.5",
      description: "Interest rate model for Yupana protocol contract.",
      authors: ["Madfish.Solutions <https://www.madfish.solutions>"],
      source: {
        tools: ["Ligo", "Flextesa"],
        location:
          "https://github.com/madfish-solutions/yupana-protocol-core/blob/v0.3.5/contracts/main/interestRate.ligo",
      },
      homepage: "https://yupana.com",
      interfaces: ["TZIP-016"],
      errors: interestRateErrors,
      views: [],
    }),
    "ascii"
  ).toString("hex"),
});

module.exports = metadata;