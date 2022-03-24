function calcUtilRate(
  const params          : utilRateParams)
                        : nat is
  block {
    const denominator : nat = get_nat_or_fail(
      params.cashF + params.borrowsF - params.reservesF,
      Errors.Math.lowLiquidityUtil
    );
  } with params.precision * params.borrowsF / denominator