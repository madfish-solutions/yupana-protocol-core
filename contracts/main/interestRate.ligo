#import  "../partial/errors.ligo" "Errors"
#include "../partial/mainTypes.ligo"
#include "../partial/commonHelpers.ligo"
#include "../partial/interestRate/interestRateMethods.ligo"

function main(
  const p               : entryRateAction;
  const s               : rateStorage)
                        : rateReturn is
  case p of
    | UpdateAdmin(params)         -> updateAdmin(params, s)
    | SetCoefficients(params)     -> setCoefficients(params, s)
    | GetBorrowRate(params)       -> getBorrowRate(params, s)
    | GetUtilizationRate(params)  -> getUtilizationRate(params, s)
    | GetSupplyRate(params)       -> getSupplyRate(params, s)
  end
