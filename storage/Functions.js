let tokenFunctions = [
  {
    index: 0,
    name: "transfer",
  },
  {
    index: 1,
    name: "updateOperators",
  },
  {
    index: 2,
    name: "getBalance",
  },
  {
    index: 3,
    name: "getTotalSupply",
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
    name: "updateRateAdmin",
  },
  {
    index: 1,
    name: "updateRateYToken",
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
