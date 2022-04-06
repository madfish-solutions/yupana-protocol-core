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
#if OLD_STYLE_VIEW
    | ReceivePrice(params)    -> receivePrice(params, s)
#endif
  end
