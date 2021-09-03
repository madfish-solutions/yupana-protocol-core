#include "../partial/MainTypes.ligo"
#include "../partial/InterestRate/InterestRateMethods.ligo"

function main(
  const p               : entryRateAction;
  const s               : rateStorage)
                        : rateReturn is
  case p of
    | UpdateRateAdmin(params) -> updateRateAdmin(params, s)
    | UpdateRateYToken(params) -> updateRateYToken(params, s)
    | SetCoefficients(params) -> setCoefficients(params, s)
    | GetBorrowRate(params) -> getBorrowRate(params, s)
    | GetUtilizationRate(params) -> getUtilizationRate(params, s)
    | GetSupplyRate(params) -> getSupplyRate(params, s)
    | UpdReserveFactor(params) -> updReserveFactor(params, s)
  end
