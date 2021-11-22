let tokenFunctions = [
  {
    index: 0,
    name: "transfer",
  },
  {
    index: 1,
    name: "update_operators",
  },
  {
    index: 2,
    name: "getBalance",
  },
  {
    index: 3,
    name: "get_total_supply",
  },
];

let yTokenFunctions = [
  {
    index: 0,
    name: "mint",
  },
  {
    index: 1,
    name: "redeem",
  },
  {
    index: 2,
    name: "borrow",
  },
  {
    index: 3,
    name: "repay",
  },
  {
    index: 4,
    name: "liquidate",
  },
  {
    index: 5,
    name: "enterMarket",
  },
  {
    index: 6,
    name: "exitMarket",
  },
  {
    index: 7,
    name: "setAdmin",
  },
  {
    index: 8,
    name: "withdrawReserve",
  },
  {
    index: 9,
    name: "addMarket",
  },
  {
    index: 10,
    name: "updateMetadata",
  },
  {
    index: 11,
    name: "setTokenFactors",
  },
  {
    index: 12,
    name: "setGlobalFactors",
  },
  {
    index: 13,
    name: "setBorrowPause",
  },
];

let proxyFunctions = [
  {
    index: 0,
    name: "updateAdmin",
  },
  {
    index: 1,
    name: "updateOracle",
  },
  {
    index: 2,
    name: "updateYToken",
  },
  {
    index: 3,
    name: "updatePair",
  },
  {
    index: 4,
    name: "getPrice",
  },
  {
    index: 5,
    name: "receivePrice",
  },
];

let interestFunctions = [
  {
    index: 0,
    name: "updateAdmin",
  },
  {
    index: 1,
    name: "updateYToken",
  },
  {
    index: 2,
    name: "setCoefficients",
  },
  {
    index: 3,
    name: "getBorrowRate",
  },
  {
    index: 4,
    name: "getUtilizationRate",
  },
  {
    index: 5,
    name: "getSupplyRate",
  },
  {
    index: 6,
    name: "ensuredSupplyRate",
  },
  {
    index: 7,
    name: "updReserveFactor",
  },
];

module.exports.functions = {
  token: tokenFunctions,
  yToken: yTokenFunctions,
  proxy: proxyFunctions,
  interestRate: interestFunctions,
};
