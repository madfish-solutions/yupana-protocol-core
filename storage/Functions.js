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
  {
    index: 7,
    name: "seize",
  },
  {
    index: 8,
    name: "updateControllerState",
  }
];

let useControllerFunctions = [
  {
    index: 0,
    name: "updatePrice",
  },
  {
    index: 1,
    name: "setOracle",
  },
  {
    index: 2,
    name: "register",
  },
  {
    index: 3,
    name: "updateQToken",
  },
  {
    index: 4,
    name: "exitMarket",
  },
  {
    index: 5,
    name: "safeMint",
  },
  {
    index: 6,
    name: "safeRedeem",
  },
  {
    index: 7,
    name: "redeemMiddle",
  },
  {
    index: 8,
    name: "ensuredRedeem",
  },
  {
    index: 9,
    name: "safeBorrow",
  },
  {
    index: 10,
    name: "borrowMiddle",
  },
  {
    index: 11,
    name: "ensuredBorrow",
  },
  {
    index: 12,
    name: "safeRepay",
  },
  {
    index: 13,
    name: "safeLiquidate",
  },
  {
    index: 14,
    name: "liquidateMiddle",
  },
  {
    index: 15,
    name: "ensuredLiquidate",
  },
  {
    index: 16,
    name: "safeSeize",
  }
];

module.exports.functions = {
  token: tokenFunctions,
  use: useFunctions,
  useController: useControllerFunctions
};