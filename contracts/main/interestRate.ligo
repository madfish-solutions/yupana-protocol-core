#include "../partial/MainTypes.ligo"
#include "../partial/InterestRate/InterestRateMethods.ligo"

[@inline] function setInterestAction (
  const idx             : nat;
  const f               : rateFunc;
  var s                 : fullRateStorage)
                        : fullRateReturn is
  block {
    if Tezos.sender = s.storage.admin then
      case s.rateLambdas[idx] of
        Some(_n) -> failwith("interest/interestRate-function-not-set")
        | None -> s.rateLambdas[idx] := f
      end;
    else failwith("interest/you-not-admin")
  } with (noOperations, s)

[@inline] function middleRate(
  const p               : rateAction;
  var s                 : fullRateStorage)
                        : fullRateReturn is
  block {
    const idx : nat = case p of
      (* TODO: use functions instead of lambdas *)
      | UpdateRateAdmin(_addr) -> 0n
      | UpdateRateYToken(_addr) -> 1n
      | SetCoefficients(_setCoeffParams) -> 2n
      (* TODO: let's join the 3 method below into single method getRates *)
      | GetBorrowRate(_rateParams) -> 3n
      | GetUtilizationRate(_rateParams) -> 4n
      | GetSupplyRate(_rateParams) -> 5n
      | EnsuredSupplyRate(_rateParams) -> 6n
      | UpdReserveFactor(_amt) -> 7n
    end;
    const res : rateReturn = case s.rateLambdas[idx] of
      Some(f) -> f(p, s.storage)
      | None -> (
        failwith(
            "interestRate/middle-function-not-set"
        ) : rateReturn
      )
    end;
    s.storage := res.1;
  } with (res.0, s)

(* TODO: prefer not to use lambdas *)
function main(
  const p               : entryRateAction;
  const s               : fullRateStorage)
                        : fullRateReturn is
  case p of
    | RateUse(params)  -> middleRate(params, s)
    | SetInterestAction(params) -> setInterestAction(params.index, params.func, s)
  end
