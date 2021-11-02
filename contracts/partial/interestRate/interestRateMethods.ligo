[@inline] function mustBeAdmin(
  const s               : rateStorage)
                        : unit is
  if Tezos.sender =/= s.admin
  then failwith("interestRate/not-admin")
  else unit

[@inline] function calcUtilRate(
  const borrowsFloat    : nat;
  const cashFloat       : nat;
  const reservesFloat   : nat;
  const precision        : nat)
                        : nat is
  block {
    const formula : nat =
    case is_nat(cashFloat + borrowsFloat - reservesFloat) of
      | None -> (failwith("interestRate-utilRate/amount-is-very-large") : nat)
      | Some(value) -> value
    end;
  } with precision * borrowsFloat / formula

[@inline] function calcBorrowRate(
  const borrowsFloat    : nat;
  const cashFloat       : nat;
  const reservesFloat   : nat;
  const precision        : nat;
  const s               : rateStorage)
                        : nat is
  block {
    const utilizationRateFloat : nat = calcUtilRate(
      borrowsFloat,
      cashFloat,
      reservesFloat,
      precision
    );
    var borrowRateFloat : nat := 0n;

    if utilizationRateFloat < s.kickRateFloat
    then borrowRateFloat := (s.baseRateFloat + (utilizationRateFloat * s.multiplierFloat) / precision);
    else block {
      const utilizationSubKick : nat =
      case is_nat(utilizationRateFloat - s.kickRateFloat) of
        | None -> (failwith("interestRate-borrow/amount-is-very-large") : nat)
        | Some(value) -> value
      end;

      borrowRateFloat := ((s.kickRateFloat * s.multiplierFloat / precision + s.baseRateFloat) +
      (utilizationSubKick * s.jumpMultiplierFloat) / precision);
    }

  } with borrowRateFloat

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
    s.kickRateFloat := param.kickRateFloat;
    s.baseRateFloat := param.baseRateFloat;
    s.multiplierFloat := param.multiplierFloat;
    s.jumpMultiplierFloat := param.jumpMultiplierFloat;
  } with (noOperations, s)

function getUtilizationRate(
  const param           : rateParams;
  const s               : rateStorage)
                        : rateReturn is
  block {
    const utilizationRateFloat : nat = calcUtilRate(
      param.borrowsFloat,
      param.cashFloat,
      param.reservesFloat,
      param.precision
    );
    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = utilizationRateFloat;
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
    const borrowRateFloat : nat = calcBorrowRate(
      param.borrowsFloat,
      param.cashFloat,
      param.reservesFloat,
      param.precision,
      s
    );

    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = borrowRateFloat;
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
    const borrowRateFloat : nat = calcBorrowRate(
      param.borrowsFloat,
      param.cashFloat,
      param.reservesFloat,
      param.precision,
      s
    );
    const utilizationRateFloat : nat = calcUtilRate(
      param.borrowsFloat,
      param.cashFloat,
      param.reservesFloat,
      param.precision
    );

    const precisionSubReserve : nat =
    case is_nat(param.precision - param.reserveFactorFloat) of
      | None -> (failwith("fa2/amount-is-very-large") : nat)
      | Some(value) -> value
    end;


    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = borrowRateFloat * utilizationRateFloat *
            precisionSubReserve;
        ],
        0mutez,
        param.callback
      )
    ];
  } with (operations, s)
