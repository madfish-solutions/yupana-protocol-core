module FA2 is {
  const notOperator              : string = "FA2_NOT_OPERATOR";
  const undefined                : string = "FA2_TOKEN_UNDEFINED";
  const notOwner                 : string = "FA2_NOT_OWNER";
  const lowBalance               : string = "FA2_NOT_ENOUGH_BALANCE";
  const notAdmin                 : string = "FA2_NOT_ADMIN";
  const wrongContract            : string = "NOT_FA2_CONTRACT";
}

module FA12 is {
  const lowBalance               : string = "FA12_NOT_ENOUGH_BALANCE";
  const lowAllowance             : string = "FA12_NOT_ENOUGH_ALLOWANCE";
  const unsafeAllowance          : string = "FA12_UNSAFE_ALLOWANCE_CHANGE";
  const wrongContract            : string = "NOT_FA12_CONTRACT";
}

module YToken is {
  const notAdmin                 : string = "Y_NOT_ADMIN";
  const notAdminOrCandidate      : string = "Y_NOT_ADMIN_OR_CANDIDATE";
  const noCandidate              : string = "Y_NO_CANDIDATE";
  const lambdaSet                : string = "Y_LAMBDA_ALREADY_SET";
  const lambdaNotSet             : string = "Y_LAMBDA_NOT_SET_YET";
  const unpackLambdaFailed       : string = "Y_CANT_UNPACK_LAMBDA";
  const tokenAlreadyAdded        : string = "Y_DUP_ASSET";
  const needUpdate               : string = "Y_NEED_UPDATE";
  const collateralTaken          : string = "Y_TOKEN_TAKEN_AS_COLLATERAL";
  const zeroAmount               : string = "Y_ZERO_AMOUNT";
  const borrowRate404            : string = "Y_CANT_GET_IR_getBorrowRate";
  const redeemExceeds            : string = "Y_ALLOWED_REDEEM_EXCEEDS";
  const debtExceeds              : string = "Y_PERMITTED_DEBT_EXCEEDS";
  const noCollateral             : string = "Y_NO_COLLATERAL";
  const unpaidDebt               : string = "Y_DEBT_NOT_REPAID";
  const wrongUpdateState         : string = "Y_INTEREST_UPDATE_STATE";
  const lowLiquidity             : string = "Y_LOW_LIQUIDITY";
  const deadlineReached          : string = "Y_DEADLINE_EXPIRED";
  const undefined                : string = "Y_TOKEN_UNDEFINED";
  const highReceived             : string = "Y_HIGH_MIN_RECEIVED";
  const maxMarketLimit           : string = "Y_MAX_MARKET_LIMIT";
  const borrowPaused             : string = "Y_BORROW_PAUSED";
  const borrowerNotLiquidator    : string = "Y_BORROWER_CANNOT_BE_LIQUIDATOR";
  const marketId404              : string = "Y_MARKET_UNDEFINED";
  const repayOverflow            : string = "Y_TOO_MUCH_REPAY";
  const highSeize                : string = "Y_HIGH_MIN_SEIZED";
  const notProxy                 : string = "Y_NOT_PROXY";
  const notIR                    : string = "Y_NOT_INTEREST_RATE";
  const highBorrowRate           : string = "Y_BORROW_RATE_ABSURDLY_HIGH";
  const cantLiquidate            : string = "Y_LIQUIDATION_NOT_ACHIEVED";
  const lowReserves              : string = "Y_LOW_RESERVES";
  const lowBalance               : string = "Y_TOKEN_NOT_ENOUGH_BALANCE";
  const lowSupply                : string = "Y_TOKEN_LOW_TOTAL_SUPPLY";
  const lowLiquidity             : string = "Y_TOKEN_LOW_LIQUIDITY";
  const lowBorrowAmount          : string = "Y_TOKEN_LOW_BORROW_AMOUNT";
  const lowBorrowerBalanceS      : string = "Y_TOKEN_LOW_BORROWER_BALANCE_SEIZE";
  const lowBorrowerBalanceR      : string = "Y_TOKEN_LOW_BORROWER_BALANCE_RESERVES";
  const lowTotalBorrow           : string = "Y_TOKEN_LOW_TOTAL_BORROWED";
  const timeOverflow             : string = "Y_TIME_OVERFLOW";
}

module Proxy is {
  const notAdmin                 : string = "P_NOT_ADMIN";
  const notOracle                : string = "P_NOT_ORACLE";
  const wrongYContract           : string = "P_NOT_YTOKEN_CONTRACT";
  const wrongOContract           : string = "P_NOT_ORACLE_CONTRACT";
  module PairCheck is {
    const decimals               : string = "DECIMALS_NOT_DEFINED";
    const pairString             : string = "STRING_NOT_DEFINED";
    const tokenId                : string = "TOKEN_ID_NOT_DEFINED";
  }
}

module InterestRate is {
  const notAdmin                 : string = "IR_NOT_ADMIN";
}

module Math is {
  const ceilDivision             : string = "MATH_CEIL_DIV_FAIL";
  const lowLiquidityUtil         : string = "UTIL_RATE_LOW_LIQUIDITY";
  const lowUtilRateKink          : string = "LOW_UTIL_RATE_AGAINST_KINK";
  const lowPrecisionReserve      : string = "LOW_PRECISION_AGAINST_RESERVES_FACTOR";
  const lowLiquidityReserve      : string = "LOW_LIQUIDITY_AGAINST_RESERVES";
}