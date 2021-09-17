[@inline] function getReserveFactorContract(
  const yToken          : address)
                        : contract(nat) is
  case (
    Tezos.get_entrypoint_opt("%getReserveFactor", yToken)
                        : option(contract(nat))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("interestRate/cant-get-yToken-entrypoint") : contract(nat)
    )
  end;

[@inline] function getEnsuredSupplyRateEntrypoint(
  const selfAddress     : address)
                        : contract(entryRateAction) is
  case (
    Tezos.get_entrypoint_opt("%rateUse", selfAddress)
                        : option(contract(entryRateAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("interestRate/cant-get-ensuredSupplyRate-entrypoint")
                        : contract(entryRateAction)
    )
  end;

[@inline] function varifyReserveFactor(
  const s               : rateStorage)
                        : unit is
  if s.lastUpdTime > ((Tezos.now + 60) : timestamp)
  then failwith("interestRate/need-update-reserveFactorFloat")
  else unit

[@inline] function mustBeAdmin(
  const s               : rateStorage)
                        : unit is
  if Tezos.sender =/= s.admin
  then failwith("interestRate/not-admin")
  else unit

[@inline] function calctBorrowRate(
  const borrowsFloat    : nat;
  const cashFloat       : nat;
  const reservesFloat   : nat;
  const accuracy        : nat;
  const s               : rateStorage)
                        : nat is
  block {
    const utilizationRateFloat : nat = accuracy * borrowsFloat / abs(cashFloat + borrowsFloat - reservesFloat);
    var borrowRateFloat : nat := 0n;

    if utilizationRateFloat < s.kickRateFloat
    then borrowRateFloat := (s.baseRateFloat + (utilizationRateFloat * s.multiplierFloat) / accuracy);
    else borrowRateFloat := ((s.kickRateFloat * s.multiplierFloat / accuracy + s.baseRateFloat) +
      (abs(utilizationRateFloat - s.kickRateFloat) * s.jumpMultiplierFloat) / accuracy);

  } with borrowRateFloat

function updateRateAdmin(
  const addr            : address;
  var s                 : rateStorage)
                        : rateReturn is
  block {
    mustBeAdmin(s);
    s.admin := addr;
  } with (noOperations, s)

function updateRateYToken(
  const addr            : address;
  var s                 : rateStorage)
                        : rateReturn is
  block {
    mustBeAdmin(s);
    s.yToken := addr;
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
    const utilizationRateFloat : nat = param.accuracy * param.borrowsFloat
      / abs(param.cashFloat + param.borrowsFloat - param.reservesFloat);
    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = utilizationRateFloat;
        ],
        0mutez,
        param.contract
      )
    ];
  } with (operations, s)

function getBorrowRate(
  const param           : rateParams;
  const s               : rateStorage)
                        : rateReturn is
  block {
    const borrowRateFloat : nat = calctBorrowRate(
      param.borrowsFloat,
      param.cashFloat,
      param.reservesFloat,
      param.accuracy,
      s
    );

    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = borrowRateFloat;
        ],
        0mutez,
        param.contract
      )
    ];
  } with (operations, s)

function getSupplyRate(
  const param           : rateParams;
  const s               : rateStorage)
                        : rateReturn is
  block {
    varifyReserveFactor(s);

    const borrowRateFloat : nat = calctBorrowRate(
      param.borrowsFloat,
      param.cashFloat,
      param.reservesFloat,
      param.accuracy,
      s
    );
    const utilizationRateFloat : nat = param.accuracy * param.borrowsFloat
      / abs(param.cashFloat + param.borrowsFloat - param.reservesFloat);
    const supplyRateFloat : nat = borrowRateFloat * utilizationRateFloat *
      abs(accuracy - s.reserveFactorFloat);

    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = supplyRateFloat;
        ],
        0mutez,
        param.contract
      )
    ];
  } with (operations, s)

function updReserveFactor(
  const amt             : nat;
  var s                 : rateStorage)
                        : rateReturn is
  block {
    if Tezos.sender = s.yToken
    then block {
      s.reserveFactorFloat := amt;
      s.lastUpdTime := Tezos.now;
    }
    else failwith("interestRate/not-yToken")
  } with (noOperations, s)
