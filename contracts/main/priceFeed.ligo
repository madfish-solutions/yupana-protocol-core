#include "../partial/MainTypes.ligo"
#include "../partial/Proxy/PriceFeedMethods.ligo"

[@inline] function setProxyAction (
  const idx : nat;
  const f               : proxyFunc;
  var s                 : fullProxyStorage)
                        : fullProxyReturn is
  block {
    if Tezos.sender = s.storage.admin then
      case s.proxyLambdas[idx] of
        Some(_n) -> failwith("ProxyFunctionNotSet")
        | None -> s.proxyLambdas[idx] := f
      end;
    else failwith("YouNotAdmin(setProxyAction)")
  } with (noOperations, s)

[@inline] function middleProxy(
  const p               : proxyAction;
  const this            : address;
  var s                 : fullProxyStorage)
                        : fullProxyReturn is
  block {
    const idx : nat = case p of
      | UpdateAdmin(_addr) -> 0n
      | UpdatePair(_pairParam) -> 1n
      | GetPrice(_tokenId) -> 2n
      | ReceivePrice(_oracleParam) -> 3n
    end;
    const res : proxyReturn = case s.proxyLambdas[idx] of
      Some(f) -> f(p, s.storage, this)
      | None -> (
        failwith("proxy/middle-function-not-set-in-middleProxy") : proxyReturn
      )
    end;
    s.storage := res.1;
  } with (res.0, s)

function main(
  const p               : entryProxyAction;
  const s               : fullProxyStorage)
                        : fullProxyReturn is
  block {
    const this : address = Tezos.self_address;
  } with case p of
      | ProxyUse(params)  -> middleProxy(params, this, s)
      | SetProxyAction(params) -> setProxyAction(params.index, params.func, s)
    end
