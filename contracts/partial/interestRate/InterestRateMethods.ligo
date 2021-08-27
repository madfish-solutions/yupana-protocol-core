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
  then failwith("interestRate/need-update-reserveFactor")
  else unit

[@inline] function mustBeAdmin(
  const s               : rateStorage)
                        : unit is
  if Tezos.sender =/= s.admin
  then failwith("interestRate/not-admin")
  else unit

[@inline] function calctBorrowRate(
  const borrows         : nat;
  const cash            : nat;
  const reserves        : nat;
  const accuracy       : nat;
  const s               : rateStorage)
                        : nat is
  block {
    const utilizationRate : nat = abs(cash + borrows - reserves)
      / accuracy * borrows;
    var borrowRate : nat := 0n;

    if utilizationRate < s.kickRate
    then borrowRate := s.baseRate + (utilizationRate * s.multiplier);
    else borrowRate := (s.kickRate * s.multiplier + s.baseRate) +
      (abs(utilizationRate - s.kickRate) * s.jumpMultiplier)

  } with borrowRate

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
    s.kickRate := param.kickRate;
    s.baseRate := param.baseRate;
    s.multiplier := param.multiplier;
    s.jumpMultiplier := param.jumpMultiplier;
  } with (noOperations, s)

function getUtilizationRate(
  const param           : rateParams;
  const s               : rateStorage)
                        : rateReturn is
  block {
    const utilizationRate : nat = abs(
      param.cash + param.borrows - param.reserves
    ) / param.accuracy * param.borrows;
    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = utilizationRate;
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
    const borrowRate : nat = calctBorrowRate(
      param.borrows,
      param.cash,
      param.reserves,
      param.accuracy,
      s
    );

    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = borrowRate;
        ],
        0mutez,
        param.contract
      )
    ];
  } with (operations, s)

function callReserveFactor(
  const param           : rateParams;
  const s               : rateStorage)
                        : rateReturn is
  block {
    var operations : list(operation) := list[
      Tezos.transaction(
        param.tokenId,
        0mutez,
        getReserveFactorContract(s.yToken)
      )
    ];
  } with (operations, s)

function getSupplyRate(
  const param           : rateParams;
  const s               : rateStorage)
                        : rateReturn is
  block {
    varifyReserveFactor(s);

    const borrowRate : nat = calctBorrowRate(
      param.borrows,
      param.cash,
      param.reserves,
      param.accuracy,
      s
    );
    const utilizationRate : nat = abs(
      param.cash + param.borrows - param.reserves
    ) / param.accuracy * param.borrows;
    const supplyRate : nat = borrowRate * utilizationRate *
      abs(accuracy - s.reserveFactor);

    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = supplyRate;
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
      s.reserveFactor := amt;
      s.lastUpdTime := Tezos.now;
    }
    else failwith("interestRate/not-yToken")
  } with (noOperations, s)
