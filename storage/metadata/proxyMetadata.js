const { MichelsonMap } = require("@taquito/michelson-encoder");

const proxyErrors = require("./proxyTZIP16Errors");

const metadata = MichelsonMap.fromLiteral({
  "": Buffer.from("tezos-storage:yupana-proxy", "ascii").toString("hex"),
  "yupana-proxy": Buffer.from(
    JSON.stringify({
      name: "Yupana oracle proxy",
      version: "v1.0.0",
      description: "Proxy of Harbinger oracle for Yupana protocol contract.",
      authors: ["Madfish.Solutions <https://www.madfish.solutions>"],
      source: {
        tools: ["Ligo", "Flextesa"],
        location:
          "https://github.com/madfish-solutions/yupana-protocol-core/blob/master/contracts/main/priceFeed.ligo",
      },
      homepage: "https://yupana.com",
      interfaces: ["TZIP-16"],
      errors: proxyErrors,
      views: [],
    }),
    "ascii"
  ).toString("hex"),
});

module.exports = metadata;