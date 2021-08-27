[@inline] function getReserveFactorContract(
  const yToken          : address)
                        : contract(nat) is
  case (
    Tezos.get_entrypoint_opt("%getReserveFactor", yToken)
                        : option(contract(nat))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("cant-get-yToken-entrypoint") : contract(nat)
    )
  end;

[@inline] function getEnsuredSupplyRateEntrypoint(
  const selfAddress     : address)
                        : contract(rateAction) is
  case (
    Tezos.get_entrypoint_opt("%rateUse", selfAddress)
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
  const borrows         : nat;
  const cash            : nat;
  const reserves        : nat;
  (* TODO : request accuracy as an argument *)
  const s               : rateStorage)
                        : nat is
  block {
    (* TODO: calculate with accuracy *)
    const utilizationRate : nat = abs(cash + borrows - reserves) / borrows;
    var borrowRate : nat := 0n;

    if utilizationRate < s.kickRate
    then borrowRate := s.baseRate + (utilizationRate * s.multiplier);
    else borrowRate := (s.kickRate * s.multiplier + s.baseRate) +
      (abs(utilizationRate - s.kickRate) * s.jumpMultiplier)

  } with borrowRate

function updateRateAdmin(
  const p               : rateAction;
  var s                 : rateStorage)
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

function updateRateYToken(
  const p               : rateAction;
  var s                 : rateStorage)
                        : rateReturn is
  block {
    case p of
      UpdateRateYToken(addr) -> {
        mustBeAdmin(s);
        s.yToken := addr;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function setCoefficients(
  const p               : rateAction;
  var s                 : rateStorage)
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
  const s               : rateStorage)
  (* TODO : request accuracy as an argument *)
                        : rateReturn is
  block {
    var operations : list(operation) := list[];
      case p of
        GetUtilizationRate(rateParams) -> {
          (* TODO: calculate with accuracy *)
          const utilizationRate : nat = abs(
            rateParams.cash + rateParams.borrows - rateParams.reserves
          ) / rateParams.borrows;
          operations := list[
            Tezos.transaction(record[
                tokenId = rateParams.tokenId;
                amount = utilizationRate;
              ],
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
  (* TODO : request accuracy as an argument *)
  const s               : rateStorage)
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
            Tezos.transaction(record[
                tokenId = rateParams.tokenId;
                amount = borrowRate;
              ],
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
  const s               : rateStorage)
                        : rateReturn is
  block {
    var operations : list(operation) := list[];
      case p of
        GetSupplyRate(rateParams) -> {
          (* TODO : don't use callbacks; check teh last update time of the reserve factor;
          it must be updated in the batch*)
          operations := list[
            Tezos.transaction(
              rateParams.tokenId,
              0mutez,
              getReserveFactorContract(s.yToken)
            );
            Tezos.transaction(
              EnsuredSupplyRate(record [
                  tokenId = rateParams.tokenId;
                  borrows = rateParams.borrows;
                  cash = rateParams.cash;
                  reserves = rateParams.reserves;
                  contract = rateParams.contract;
              ]),
              0mutez,
              getEnsuredSupplyRateEntrypoint(Tezos.self_address)
            )
          ];
        }
      | _               -> skip
    end
  } with (operations, s)

function ensuredSupplyRate(
  const p               : rateAction;
  const s               : rateStorage)
                        : rateReturn is
  block {
    var operations : list(operation) := list[];
      case p of
        EnsuredSupplyRate(rateParams) -> {
          const borrowRate : nat = calctBorrowRate(
            rateParams.borrows,
            rateParams.cash,
            rateParams.reserves,
            s
          );
          const utilizationRate : nat = abs(
            rateParams.cash + rateParams.borrows - rateParams.reserves
          ) / rateParams.borrows;
          const supplyRate : nat = borrowRate * utilizationRate *
            abs(accuracy - s.reserveFactor);

          operations := list[
            Tezos.transaction(record[
                tokenId = rateParams.tokenId;
                amount = supplyRate;
              ],
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
  var s                 : rateStorage)
                        : rateReturn is
  block {
    case p of
      UpdReserveFactor(amt) -> {
        (* TODO: ensure the response is from the yToken *)
        s.reserveFactor := amt;
      }
    | _                 -> skip
    end
  } with (noOperations, s)
