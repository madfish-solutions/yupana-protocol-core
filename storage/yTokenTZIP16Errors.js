const yTokenErrors = [
  {
    error: { string: "Y_NOT_ADMIN" },
    expansion: { string: "Sender is not admin." },
    languages: ["en"],
  },
  {
    error: { string: "Y_NOT_ADMIN_OR_CANDIDATE" },
    expansion: { string: "Sender is not admin or admin candidate." },
    languages: ["en"],
  },
  {
    error: { string: "Y_NO_CANDIDATE" },
    expansion: { string: "Admin candidate field is None." },
    languages: ["en"],
  },
  {
    error: { string: "Y_NOT_PROXY" },
    expansion: { string: "Sender is not proxy (PriceFeed) contract." },
    languages: ["en"],
  },
  {
    error: { string: "Y_NOT_INTEREST_RATE" },
    expansion: { string: "Sender is not interest rate contract." },
    languages: ["en"],
  },
  {
    error: { string: "Y_CANT_GET_IR_getBorrowRate" },
    expansion: {
      string:
        "getBorrowRate entrypoint is not available at interest rate contract.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_INTEREST_UPDATE_STATE" },
    expansion: {
      string:
        "Interest update operation has wrong state (not updating right now).",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_LAMBDA_ALREADY_SET" },
    expansion: {
      string: "Lambda function that tried to set has already been set.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_LAMBDA_NOT_SET_YET" },
    expansion: {
      string: "Lambda function that tried to call has not been set yet.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_CANT_UNPACK_LAMBDA" },
    expansion: {
      string:
        "Contract can't unpack lambda function to correspondig type (broken lambda bytes).",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_TOKEN_TAKEN_AS_COLLATERAL" },
    expansion: {
      string:
        "Current token was taken as collateral base and could not be transferred.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_NO_COLLATERAL" },
    expansion: {
      string: "Current token has not added as collateral.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_DUP_ASSET" },
    expansion: {
      string: "Current token has already been added to lending market.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_NEED_UPDATE" },
    expansion: {
      string: "Token info (interest rate or price) needs update.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_ZERO_AMOUNT" },
    expansion: {
      string: "User passed zero amount.",
    },
    languages: ["en"],
  },
];

module.exports = yTokenErrors;
