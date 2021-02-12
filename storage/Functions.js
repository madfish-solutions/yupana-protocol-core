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
    name: "enterMarket",
  },
  {
    index: 5,
    name: "exitMarket",
  },
  {
    index: 6,
    name: "safeMint",
  },
  {
    index: 7,
    name: "safeRedeem",
  },
  {
    index: 8,
    name: "redeemMiddle",
  },
  {
    index: 9,
    name: "ensuredRedeem",
  },
  {
    index: 10,
    name: "safeBorrow",
  },
  {
    index: 11,
    name: "borrowMiddle",
  },
  {
    index: 12,
    name: "ensuredBorrow",
  },
  {
    index: 13,
    name: "safeRepay",
  },
  {
    index: 14,
    name: "safeLiquidate",
  },
  {
    index: 15,
    name: "liquidateMiddle",
  },
  {
    index: 16,
    name: "ensuredLiquidate",
  }
];

module.exports.functions = {
  token: tokenFunctions,
  use: useFunctions,
  useController: useControllerFunctions
};
