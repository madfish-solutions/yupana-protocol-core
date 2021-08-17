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
  },
];

let useControllerFunctions = [
  {
    index: 0,
    name: "updatePrice",
  },
  {
    index: 1,
    name: "sendToOracle",
  },
  {
    index: 2,
    name: "setOracle",
  },
  {
    index: 3,
    name: "register",
  },
  {
    index: 4,
    name: "updateQToken",
  },
  {
    index: 5,
    name: "exitMarket",
  },
  {
    index: 6,
    name: "ensuredExitMarket",
  },
  {
    index: 7,
    name: "safeMint",
  },
  {
    index: 8,
    name: "safeRedeem",
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
    name: "ensuredBorrow",
  },
  {
    index: 12,
    name: "safeRepay",
  },
  {
    index: 13,
    name: "ensuredRepay",
  },
  {
    index: 14,
    name: "safeLiquidate",
  },
  {
    index: 15,
    name: "ensuredLiquidate",
  },
];

let proxyFunctions = [
  {
    index: 0,
    name: "updateAdmin",
  },
  {
    index: 1,
    name: "updatePair",
  },
  {
    index: 2,
    name: "getPrice",
  },
  {
    index: 3,
    name: "receivePrice",
  },
];

module.exports.functions = {
  proxy: proxyFunctions,
};
