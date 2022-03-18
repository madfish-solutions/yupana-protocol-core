module FA2 is {
  const notOperator              : string = "FA2_NOT_OPERATOR";
  const undefined                : string = "FA2_TOKEN_UNDEFINED";
  const notOwner                 : string = "FA2_NOT_OWNER";
  const insufficientBalance      : string = "FA2_INSUFFICIENT_BALANCE";
  const notAdmin                 : string = "FA2_NOT_ADMIN";
  const wrongContract            : string = "NOT_FA2_CONTRACT";
}

module FA12 is {
  const lowBalance               : string = "FA12_NOT_ENOUGH_BALANCE";
  const lowAllowance             : string = "FA12_NOT_ENOUGH_ALLOWANCE";
  const unsafeAllowance          : string = "FA12_UNSAFE_ALLOWANCE_CHANGE";
  const insufficientBalance      : string = "FA12_INSUFFICIENT_BALANCE";
  const wrongContract            : string = "NOT_FA12_CONTRACT";
}

module Math {
  const ceilDivision             : string = "MATH_CEIL_DIV_FAIL";
}

module yToken is {
  const notAdmin                 : string = "Y_NOT_ADMIN";
  const notAdminOrCandidate      : string = "Y_NOT_ADMIN_OR_CANDIDATE";
  const noCandidate              : string = "Y_NO_CANDIDATE";
  const lambdaSet                : string = "Y_LAMBDA_ALREADY_SET";
  const lambdaNotSet             : string = "Y_LAMBDA_NOT_SET_YET";
  const unpackLambdaFailed       : string = "Y_CANT_UNPACK_LAMBDA";
  const token_already_added      : string = "Y_DUP_ASSET";
  const needUpdate               : string = "Y_NEED_UPDATE";
  const collateralTaken          : string = "Y_TOKEN_TAKEN_AS_COLLATERAL";
  const zeroAmount               : string = "Y_ZERO_AMOUNT";
  const borrowRate404            : string = "Y_CANT_GET_IR_getBorrowRate";
  const redeemExceeds            : string = "Y_ALLOWED_REDEEM_EXCEEDS";
  const debtExceeds              : string = "Y_PERMITTED_DEBT_EXCEEDS";
  const noCollateral             : string = "Y_NO_COLLATERAL";
  const unpaidDebt               : string = "Y_DEBT_NOT_REPAID";
  const wrongUpdateState         : string = "Y_INTEREST_UPDATE_STATE";
  const lowLiquidity            : string = "Y_LOW_LIQUIDITY";
}