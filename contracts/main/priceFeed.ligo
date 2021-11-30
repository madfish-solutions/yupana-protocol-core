#include "../partial/mainTypes.ligo"
#include "../partial/proxy/priceFeedMethods.ligo"

function main(
  const p               : entryProxyAction;
  const s               : proxyStorage)
                        : proxyReturn is
  case p of
    | SetProxyAdmin(params)   -> setProxyAdmin(params, s)
    | UpdateOracle(params)    -> updateOracle(params, s)
    | UpdateYToken(params)    -> updateYToken(params, s)
    | UpdatePair(params)      -> updatePair(params, s)
    | GetPrice(params)        -> getPrice(params, s)
    | ReceivePrice(params)    -> receivePrice(params, s)
  end
