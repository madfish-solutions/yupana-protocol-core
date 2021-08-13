#include "../partial/MainTypes.ligo"
#include "../partial/InterestRate/InterestRateMethods.ligo"

[@inline] function middleRate(
  const p               : rateAction;
  const this            : address;
  var s                 : fullRateStorage)
                        : fullRateReturn is
  block {
    const idx : nat = case p of
      | UpdateRateAdmin(_addr) -> 0n
      | SetCoefficients(_setCoeffParams) -> 1n
      | GetBorrowRate(_rateParams) -> 2n
      | GetUtilizationRate(_rateParams) -> 3n
      | GetSupplyRate(_rateParams) -> 4n
      | EnsuredSupplyRate(_rateParams) -> 5n
      | UpdReserveFactor(_amt) -> 6n
    end;
    const res : rateReturn = case s.rateLambdas[idx] of
      Some(f) -> f(p, s.storage, this)
      | None -> (
        failwith(
            "interestRate/middle-function-not-set-in-middleInterestRate"
        ) : rateReturn
      )
    end;
    s.storage := res.1;
  } with (res.0, s)


function main(
  const p               : entryRateAction;
  const s               : fullRateStorage)
                        : fullRateReturn is
  block {
    const this : address = Tezos.self_address;
  } with case p of
      | RateUse(params)  -> middleRate(params, this, s)
    end
