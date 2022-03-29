const proxyErrors = [
  {
    error: { string: "P_NOT_ADMIN" },
    expansion: { string: "Sender is not admin." },
    languages: ["en"],
  },
  {
    error: { string: "P_NOT_ORACLE" },
    expansion: { string: "Sender is not oracle." },
    languages: ["en"],
  },
  {
    error: { string: "P_NOT_YTOKEN_CONTRACT" },
    expansion: {
      string:
        "Stored yToken address has not required entrypoints (probably not Yupana contract).",
    },
    languages: ["en"],
  },
  {
    error: { string: "P_NOT_ORACLE_CONTRACT" },
    expansion: {
      string:
        "Stored oracle address has not required entrypoints (probably not Harbinger oracle contract).",
    },
    languages: ["en"],
  },
  {
    error: { string: "P_OLD_PRICE_RECEIVED" },
    expansion: { string: "Price, received from oracle is too old." },
    languages: ["en"],
  },
  {
    error: { string: "DECIMALS_NOT_DEFINED" },
    expansion: {
      string:
        "Decimal precision for pair name not stored in corresponding contract big_map storage.",
    },
    languages: ["en"],
  },
  {
    error: { string: "STRING_NOT_DEFINED" },
    expansion: {
      string:
        "Pair name precision for tokenId not stored in corresponding contract big_map storage.",
    },
    languages: ["en"],
  },
  {
    error: { string: "TOKEN_ID_NOT_DEFINED" },
    expansion: {
      string:
        "TokenId for pair name not stored in corresponding contract big_map storage.",
    },
    languages: ["en"],
  }
];

module.exports = proxyErrors;
