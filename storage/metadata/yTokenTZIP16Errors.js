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
        "Contract can't unpack lambda function to corresponding type (broken lambda bytes).",
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
  {
    error: { string: "Y_DEBT_NOT_REPAID" },
    expansion: {
      string:
        "User couldn't exit market when has unpaid debt in underlying market token.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_BORROW_PAUSED" },
    expansion: {
      string: "Market token is paused for borrowing. (Market frozen)",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_BORROWER_CANNOT_BE_LIQUIDATOR" },
    expansion: {
      string: "Borrowers can't liquidate themselves.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_MARKET_UNDEFINED" },
    expansion: {
      string:
        "Passed token identifier should be in range [0, lastTokenId). (Borrow and collateral tokenIDs should be less than lastTokenId)",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_TOKEN_UNDEFINED" },
    expansion: {
      string:
        "Passed token identifier not belongs to any existing markets. (tokenID should be less than lastTokenId)",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_ALLOWED_REDEEM_EXCEEDS" },
    expansion: {
      string:
        "User couldn't redeem collateral tokens that guarantees the users debt.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_PERMITTED_DEBT_EXCEEDS" },
    expansion: {
      string:
        "User couldn't borrow more tokens that guarantees the users collateral tokens.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_MAX_MARKET_LIMIT" },
    expansion: {
      string:
        "User reached limit number of markets that can be use as collateral or borrow.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_TOO_MUCH_REPAY" },
    expansion: {
      string: "User sent more tokens than needed to repay or liquidate debt.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_TIME_OVERFLOW" },
    expansion: {
      string:
        "Time when token interestrate was updated more than now. (Should be never reached)",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_DEADLINE_EXPIRED" },
    expansion: {
      string: "Deadline of current contract call reached.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_HIGH_MIN_SEIZED" },
    expansion: {
      string:
        "Min seized param grater than real calculated amount of seized tokens.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_HIGH_MIN_RECEIVED" },
    expansion: {
      string:
        "Min received param grater than real calculated amount of received tokens.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_BORROW_RATE_ABSURDLY_HIGH" },
    expansion: {
      string:
        "Borrow rate received from Interest Rate contract is absurdly high. (More than maxBorrowRate of token)",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_LIQUIDATION_NOT_ACHIEVED" },
    expansion: {
      string: "Current debt not reached liquidation conditions.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_LOW_RESERVES" },
    expansion: {
      string: "Passed amount is greater than available reserves.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_LOW_LIQUIDITY" },
    expansion: {
      string: "Not enough liquidity to perform operation.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_TOKEN_NOT_ENOUGH_BALANCE" },
    expansion: {
      string:
        "Not enough users balance of corresponding yTokens to perform operation.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_TOKEN_LOW_TOTAL_SUPPLY" },
    expansion: {
      string:
        "Not enough total supply of corresponding yTokens to perform operation.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_TOKEN_LOW_BORROW_AMOUNT" },
    expansion: {
      string: "Passed amount greater than available borrower balance.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_TOKEN_LOW_BORROW_AMOUNT" },
    expansion: {
      string: "Passed amount greater than borrower balance.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_TOKEN_LOW_BORROWER_BALANCE_SEIZE" },
    expansion: {
      string: "Seized tokens is greater than borrower balance.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_TOKEN_LOW_BORROWER_BALANCE_RESERVES" },
    expansion: {
      string: "Reserved tokens greater than borrower balance.",
    },
    languages: ["en"],
  },
  {
    error: { string: "Y_TOKEN_LOW_TOTAL_BORROWED" },
    expansion: {
      string:
        "Amount of tokens to repay or liquidate greater than total borrowed tokens amount.",
    },
    languages: ["en"],
  },
  {
    error: { string: "FA2_NOT_OPERATOR" },
    expansion: {
      string: "Sender is not allowed to operate users tokens.",
    },
    languages: ["en"],
  },
  {
    error: { string: "FA2_TOKEN_UNDEFINED" },
    expansion: {
      string: "FA2 token with passed tokenId does not exist.",
    },
    languages: ["en"],
  },
  {
    error: { string: "FA2_INSUFFICIENT_BALANCE" },
    expansion: {
      string: "User hasn't needed amount of tokens.",
    },
    languages: ["en"],
  },
  {
    error: { string: "FA2_NOT_OWNER" },
    expansion: {
      string: "Sender is not owner of current token account.",
    },
    languages: ["en"],
  },
  {
    error: { string: "NOT_FA2_CONTRACT" },
    expansion: {
      string: "Passed contract address is not FA2 token contract.",
    },
    languages: ["en"],
  },
  {
    error: { string: "NOT_FA12_CONTRACT" },
    expansion: {
      string: "Passed contract address is not FA12 token contract.",
    },
    languages: ["en"],
  },
  {
    error: { string: "LOW_LIQUIDITY_AGAINST_RESERVES" },
    expansion: {
      string:
        "Total reserves is greater than sum of total liquidity and total borrowed of token.",
    },
    languages: ["en"],
  },
  {
    error: { string: "MATH_CEIL_DIV_FAIL" },
    expansion: {
      string: "Failed division of two natural numbers.",
    },
    languages: ["en"],
  },
];

module.exports = yTokenErrors;
