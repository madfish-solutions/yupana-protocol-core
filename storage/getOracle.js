const { alice } = require("../scripts/sandbox/accounts");
const { MichelsonMap } = require("@taquito/michelson-encoder");

// module.exports = {
//   tokens: MichelsonMap.fromLiteral({}),
//   returnAddress: alice.pkh,
// };
let storage = {
  assetCodes: [
    "BAT-USDC",
    "BTC-USD",
    "COMP-USD",
    "DAI-USDC",
    "ETH-USD",
    "KNC-USD",
    "LINK-USD",
    "REP-USD",
    "XTZ-USD",
    "ZRX-USD",
  ],
  assetMap: MichelsonMap.fromLiteral({
    ["ETH-USD"]: {
      computedPrice: 4120747980,
      lastUpdateTime: "2021-10-22T07:01:00Z",
      prices: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
      volumes: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
    },
    ["DAI-USDC"]: {
      computedPrice: 999843,
      lastUpdateTime: "2021-10-22T06:45:00Z",
      prices: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
      volumes: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
    },
    ["XTZ-USD"]: {
      computedPrice: 6817004,
      lastUpdateTime: "2021-10-22T07:01:00Z",
      prices: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
      volumes: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
    },
    ["ZRX-USD"]: {
      computedPrice: 1017038,
      lastUpdateTime: "2021-10-22T07:01:00Z",
      prices: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
      volumes: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
    },
    ["LINK-USD"]: {
      computedPrice: 28960520,
      lastUpdateTime: "2021-10-22T07:01:00Z",
      prices: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
      volumes: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
    },
    ["BTC-USD"]: {
      computedPrice: 62762042028,
      lastUpdateTime: "2021-10-22T07:01:00Z",
      prices: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
      volumes: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
    },
    ["REP-USD"]: {
      computedPrice: 24580998,
      lastUpdateTime: "2021-10-22T07:00:00Z",
      prices: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
      volumes: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
    },
    ["BAT-USDC"]: {
      computedPrice: 699505,
      lastUpdateTime: "2021-10-22T07:01:00Z",
      prices: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
      volumes: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
    },
    ["COMP-USD"]: {
      computedPrice: 321748180,
      lastUpdateTime: "2021-10-22T07:01:00Z",
      prices: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
      volumes: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
    },
    ["KNC-USD"]: {
      computedPrice: 1635090,
      lastUpdateTime: "2021-10-22T07:01:00Z",
      prices: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
      volumes: {
        first: 0,
        last: 0,
        saved: MichelsonMap.fromLiteral({}),
        sum: 0,
      },
    },
  }),
  numDataPoints: "6",
  oracleContract: alice.pkh,
};

module.exports = storage;
