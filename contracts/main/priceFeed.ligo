#import  "../partial/errors.ligo" "Errors"
#include "../partial/mainTypes.ligo"
#include "../partial/commonHelpers.ligo"
#include "../partial/proxy/priceFeedMethods.ligo"

function main(
  const p               : entryProxyAction;
  const s               : proxyStorage)
                        : proxyReturn is
  case p of
    | SetProxyAdmin(params)   -> setProxyAdmin(params, s)
    | SetTimeLimit(params)    -> setTimeLimit(params, s)
    | UpdateOracle(params)    -> updateOracle(params, s)
    | UpdateYToken(params)    -> updateYToken(params, s)
    | UpdatePair(params)      -> updatePair(params, s)
    | GetPrice(params)        -> getPrice(params, s)
    | ReceivePrice(params)    -> receivePrice(params, s)
  end
