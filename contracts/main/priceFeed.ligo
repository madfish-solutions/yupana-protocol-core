#include "../partial/MainTypes.ligo"
#include "../partial/Proxy/PriceFeedMethods.ligo"

[@inline] function setProxyAction (
  const idx             : nat;
  const f               : proxyFunc;
  var s                 : fullProxyStorage)
                        : fullProxyReturn is
  block {
    if Tezos.sender = s.storage.admin then
      case s.proxyLambdas[idx] of
        Some(_n) -> failwith("proxy/proxy-function-not-set")
        | None -> s.proxyLambdas[idx] := f
      end;
    else failwith("proxy/you-not-admin")
  } with (noOperations, s)

[@inline] function middleProxy(
  const p               : proxyAction;
  var s                 : fullProxyStorage)
                        : fullProxyReturn is
  block {
    (* TODO: use functions instead of lambas *)
    const idx : nat = case p of
      | UpdateAdmin(_addr) -> 0n
      | UpdateOracle(_addr) -> 1n
      | UpdateYToken(_addr) -> 2n
      | UpdatePair(_pairParam) -> 3n
      | GetPrice(_tokenId) -> 4n
      | ReceivePrice(_oracleParam) -> 5n
    end;
    const res : proxyReturn = case s.proxyLambdas[idx] of
      Some(f) -> f(p, s.storage)
      | None -> (
        failwith("proxy/middle-function-not-set") : proxyReturn
      )
    end;
    s.storage := res.1;
  } with (res.0, s)

function main(
  const p               : entryProxyAction;
  const s               : fullProxyStorage)
                        : fullProxyReturn is
  case p of
    | ProxyUse(params)  -> middleProxy(params, s)
    | SetProxyAction(params) -> setProxyAction(params.index, params.func, s)
  end
