let tokenFunctions = [
  {
    index: 0,
    name: "transfer",
  },
  {
    index: 1,
    name: "approve",
  },
  {
      index: 2,
      name: "getBalance",
  },
  {
      index: 3,
      name: "getAllowance",
  },
  {
      index: 4,
      name: "getTotalSupply",
  },
];

let useFunctions = [
  {
    index: 0,
    name: "setAdmin",
  },
  {
    index: 1,
    name: "setOwner",
  },
  {
    index: 2,
    name: "mint",
  },
  {
    index: 3,
    name: "redeem",
  },
  {
    index: 4,
    name: "borrow",
  },
  {
    index: 5,
    name: "repay",
  },
  {
    index: 6,
    name: "liquidate",
  },
];

module.exports.functions = {
  token: tokenFunctions,
  use: useFunctions,
};
