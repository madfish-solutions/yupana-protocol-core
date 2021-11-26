[@inline] function mustBeAdmin(
  const s               : rateStorage)
                        : unit is
  if Tezos.sender =/= s.admin
  then failwith("interestRate/not-admin")
  else unit

[@inline] function calcUtilRate(
  const borrowsF    : nat;
  const cashF       : nat;
  const reservesF   : nat;
  const precision        : nat)
                        : nat is
  block {
    const denominator : nat =
      case is_nat(cashF + borrowsF - reservesF) of
        | None -> (failwith("underflow/cashF+borrowsF") : nat)
        | Some(value) -> value
      end;
  } with precision * borrowsF / denominator

[@inline] function calcBorrowRate(
  const borrowsF    : nat;
  const cashF       : nat;
  const reservesF   : nat;
  const precision        : nat;
  const s               : rateStorage)
                        : nat is
  block {
    const utilizationRateF : nat = calcUtilRate(
      borrowsF,
      cashF,
      reservesF,
      precision
    );
    var borrowRateF : nat := 0n;

    if utilizationRateF <= s.kinkF
    then borrowRateF := (s.baseRateF + (utilizationRateF * s.multiplierF) / precision);
    else block {
      const utilizationSubkink : nat =
        case is_nat(utilizationRateF - s.kinkF) of
          | None -> (failwith("underflow/utilizationRateF") : nat)
          | Some(value) -> value
        end;

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
    const utilizationRateF : nat = calcUtilRate(
      param.borrowsF,
      param.cashF,
      param.reservesF,
      param.precision
    );
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
    const borrowRateF : nat = calcBorrowRate(
      param.borrowsF,
      param.cashF,
      param.reservesF,
      param.precision,
      s
    );
    const utilizationRateF : nat = calcUtilRate(
      param.borrowsF,
      param.cashF,
      param.reservesF,
      param.precision
    );

    const precisionSubReserve : nat =
      case is_nat(param.precision - param.reserveFactorF) of
        | None -> (failwith("underflow/precision") : nat)
        | Some(value) -> value
      end;


    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = borrowRateF * utilizationRateF *
            precisionSubReserve;
        ],
        0mutez,
        param.callback
      )
    ];
  } with (operations, s)
