[@inline] function mustBeAdmin(
  const s               : rateStorage)
                        : unit is
  require(Tezos.sender = s.admin, Errors.InterestRate.notAdmin)

[@inline] function getUtilLambda(
  const s               : rateStorage)
                        : rateLambda is
  unwrap(
    (Bytes.unpack(s.utilLambda) : option(rateLambda)),
    Errors.InterestRate.unpackLambdaFailed
  )

[@inline] function calcBorrowRate(
  const borrowsF        : nat;
  const cashF           : nat;
  const reservesF       : nat;
  const precision       : nat;
  const s               : rateStorage)
                        : nat is
  block {
    const calcUtilRate = getUtilLambda(s);
    const utilizationRateF : nat = calcUtilRate(record[
      borrowsF = borrowsF;
      cashF = cashF;
      reservesF = reservesF;
      precision = precision;
    ]);
    var borrowRateF : nat := 0n;

    if utilizationRateF <= s.kinkF
    then borrowRateF := s.baseRateF + utilizationRateF * s.multiplierF / precision;
    else {
      const utilizationSubkink : nat = get_nat_or_fail(utilizationRateF - s.kinkF, Errors.Math.lowUtilRateKink);
      borrowRateF := ((s.kinkF * s.multiplierF / precision + s.baseRateF) +
      (utilizationSubkink * s.jumpMultiplierF) / precision);
    }
  } with borrowRateF

function updateAdmin(
  const addr            : address;
  var s                 : rateStorage)
                        : rateReturn is
  block {
    mustBeAdmin(s);
    s.admin := addr;
  } with (noOperations, s)

function setCoefficients(
  const param           : setCoeffParams;
  var s                 : rateStorage)
                        : rateReturn is
  block {
    mustBeAdmin(s);
    s.kinkF := param.kinkF;
    s.baseRateF := param.baseRateF;
    s.multiplierF := param.multiplierF;
    s.jumpMultiplierF := param.jumpMultiplierF;
  } with (noOperations, s)

function getUtilizationRate(
  const param           : rateParams;
  const s               : rateStorage)
                        : rateReturn is
  block {
    const calcUtilRate = getUtilLambda(s);
    const utilizationRateF : nat = calcUtilRate(record[
      borrowsF = param.borrowsF;
      cashF = param.cashF;
      reservesF = param.reservesF;
      precision = param.precision;
    ]);
    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = utilizationRateF;
        ],
        0mutez,
        param.callback
      )
    ];
  } with (operations, s)

function getBorrowRate(
  const param           : rateParams;
  const s               : rateStorage)
                        : rateReturn is
  block {
    const borrowRateF : nat = calcBorrowRate(
      param.borrowsF,
      param.cashF,
      param.reservesF,
      param.precision,
      s
    );

    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = borrowRateF;
        ],
        0mutez,
        param.callback
      )
    ];
  } with (operations, s)

function getSupplyRate(
  const param           : rateParams;
  const s               : rateStorage)
                        : rateReturn is
  block {
    const calcUtilRate = getUtilLambda(s);
    const borrowRateF : nat = calcBorrowRate(
      param.borrowsF,
      param.cashF,
      param.reservesF,
      param.precision,
      s
    );
    const utilizationRateF : nat = calcUtilRate(record[
      borrowsF = param.borrowsF;
      cashF = param.cashF;
      reservesF = param.reservesF;
      precision = param.precision;
    ]);

    const precisionSubReserveF : nat = get_nat_or_fail(param.precision - param.reserveFactorF, Errors.Math.lowPrecisionReserve);

    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = borrowRateF * utilizationRateF *
            precisionSubReserveF / param.precision / param.precision;
        ],
        0mutez,
        param.callback
      )
    ];
  } with (operations, s)
