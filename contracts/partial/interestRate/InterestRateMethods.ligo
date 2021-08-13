[@inline] function getYtokenContract(
  const yToken          : address)
                        : contract(useParam) is
  case (
    Tezos.get_entrypoint_opt("%updateBorrowRate", yToken)
                        : option(contract(useParam))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("cant-get-yToken-entrypoint") : contract(useParam)
    )
  end;

[@inline] function getEnsuredSupplyRateEntrypoint(
  const selfAddress     : address)
                        : contract(rateAction) is
  case (
    Tezos.get_entrypoint_opt("%ensuredSupplyRate", selfAddress)
                        : option(contract(rateAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("cant-get-ensuredSupplyRate-entrypoint")
                        : contract(rateAction)
    )
  end;

[@inline] function mustBeAdmin(
  const s               : rateStorage)
                        : unit is
  block {
    if Tezos.sender =/= s.admin
    then failwith("not-admin")
    else skip;
  } with (unit)

[@inline] function calctBorrowRate(
  var borrows           : nat;
  var cash              : nat;
  var reserves          : nat;
  const s               : rateStorage)
                        : nat is
  block {
    var utilizationRate : nat := borrows / abs(cash + borrows - reserves);
    var borrowRate : nat := 0n;
    if utilizationRate < s.kickRate
    then borrowRate := s.baseRate + (utilizationRate * s.multiplier);
    else borrowRate := s.baseRate + s.kickRate * s.multiplier +
      abs(utilizationRate - s.kickRate) * s.jumpMultiplier
  } with borrowRate

function updateRateAdmin(
  const p               : rateAction;
  var s                 : rateStorage;
  const _this           : address)
                        : rateReturn is
  block {
    case p of
      UpdateRateAdmin(addr) -> {
        mustBeAdmin(s);
        s.admin := addr;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function setCoefficients(
  const p               : rateAction;
  var s                 : rateStorage;
  const _this           : address)
                        : rateReturn is
  block {
    case p of
      SetCoefficients(setCoeffParams) -> {
        mustBeAdmin(s);
        s.kickRate := setCoeffParams.kickRate;
        s.baseRate := setCoeffParams.baseRate;
        s.multiplier := setCoeffParams.multiplier;
        s.jumpMultiplier := setCoeffParams.jumpMultiplier;
      }
    | _               -> skip
    end
  } with (noOperations, s)

function getUtilizationRate(
  const p               : rateAction;
  var s                 : rateStorage;
  const _this           : address)
                        : rateReturn is
  block {
    var operations : list(operation) := list[];
      case p of
        GetUtilizationRate(rateParams) -> {
          const utilizationRate : nat = rateParams.borrows /
            abs(rateParams.cash + rateParams.borrows - rateParams.reserves);
          operations := list[
            Tezos.transaction(
              utilizationRate,
              0mutez,
              rateParams.contract
            )
          ];
        }
      | _               -> skip
    end
  } with (operations, s)

function getBorrowRate(
  const p               : rateAction;
  var s                 : rateStorage;
  const _this           : address)
                        : rateReturn is
  block {
    var operations : list(operation) := list[];
      case p of
        GetBorrowRate(rateParams) -> {
          const borrowRate : nat = calctBorrowRate(
            rateParams.borrows,
            rateParams.cash,
            rateParams.reserves,
            s
          );

          operations := list[
            Tezos.transaction(
              (tokenId, borrowRate),
              0mutez,
              rateParams.contract
            )
          ];
        }
      | _               -> skip
    end
  } with (operations, s)

function getSupplyRate(
  const p               : rateAction;
  var s                 : rateStorage;
  const this            : address)
                        : rateReturn is
  block {
    var operations : list(operation) := list[];
      case p of
        GetSupplyRate(supplyRateParams) -> {
          operations := list[
            Tezos.transaction(
              GetReserveFactor(supplyRateParams.tokenId),
              0mutez,
              getYtokenContract(s.yToken)
            );
            Tezos.transaction(
              EnsuredSupplyRate(record [
                  borrows = supplyRateParams.borrows;
                  cash = supplyRateParams.cash;
                  reserves = supplyRateParams.reserves;
                  contract = supplyRateParams.contract;
              ]),
              0mutez,
              getEnsuredSupplyRateEntrypoint(this)
            )
          ];
        }
      | _               -> skip
    end
  } with (operations, s)

function ensuredSupplyRate(
  const p               : rateAction;
  var s                 : rateStorage;
  const _this           : address)
                        : rateReturn is
  block {
    var operations : list(operation) := list[];
      case p of
        EnsuredSupplyRate(rateParams) -> {
          var borrowRate : nat := calctBorrowRate(
            rateParams.borrows,
            rateParams.cash,
            rateParams.reserves,
            s
          );
          var utilizationRate : nat := rateParams.borrows /
            abs(rateParams.cash + rateParams.borrows - rateParams.reserves);
          var supplyRate : nat := borrowRate * utilizationRate *
            abs(1n - s.reserveFactor);

          operations := list[
            Tezos.transaction(
              supplyRate,
              0mutez,
              rateParams.contract
            )
          ];
        }
      | _               -> skip
    end
  } with (operations, s)

function updReserveFactor(
  const p               : rateAction;
  var s                 : rateStorage;
  const _this           : address)
                        : rateReturn is
  block {
    case p of
      UpdReserveFactor(amt) -> {
        s.reserveFactor := amt;
      }
    | _                 -> skip
    end
  } with (noOperations, s)
