#include "../yToken/MainTypes.ligo"

type storage            is [@layout:comb] record [
  admin                 : address;
  oracle                : address;
  yToken                : address;
  pairName              : big_map(tokenId, string);
  pairId                : big_map(string, tokenId);
]

type getType is Get of string * contract(oracleParam)

type entryProxyAction is ProxyUse of proxyAction

type proxyReturn is list (operation) * storage
type proxyFunc is (proxyAction * storage * address) -> proxyReturn

type fullProxyStorage   is record [
  storage               : storage;
  proxyLambdas          : big_map(nat, proxyFunc);
]

type fullProxyReturn is list (operation) * fullProxyStorage
