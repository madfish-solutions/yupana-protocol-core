#include "/yToken/FA2Types.ligo"
#include "/yToken/LendingTypes.ligo"
#include "/interestRate/InterestRateTypes.ligo"
#include "/proxy/PriceFeedTypes.ligo"

type useAction          is
  | Mint of mainParams
  | Redeem of mainParams
  | Borrow of mainParams
  | EnsuredBorrow of mainParams
  | Repay of mainParams
  | Liquidate of liquidateParams
  | EnsuredLiquidate of liquidateParams
  | EnterMarket of tokenId
  | ExitMarket of tokenId
  | EnsuredExitMarket of tokenId

type tokenAction        is
  | ITransfer of transferParams
  | IUpdateOperators of updateOperatorParams
  | IBalanceOf of balanceParams
  | IGetTotalSupply of totalSupplyParams

type proxyAction        is
  | UpdateAdmin of address
  | UpdatePair of pairParam
  | GetPrice of tokenId
  | ReceivePrice of oracleParam

type rateAction         is
  | UpdateRateAdmin of address
  | SetCoefficients of setCoeffParams
  | GetBorrowRate of rateParams
  | GetUtilizationRate of rateParams
  | GetSupplyRate of supplyRateParams
  | EnsuredSupplyRate of rateParams
  | UpdReserveFactor of nat

type entryAction        is
  | Transfer of transferParams
  | UpdateOperators of updateOperatorParams
  | BalanceOf of balanceParams
  | GetTotalSupply of totalSupplyParams
  | UpdateInterest of tokenId
  | EnsuredUpdateInterest of tokenId
  | UpdateBorrowRate of mainParams
  | GetReserveFactor of tokenId
  | UpdatePrice of mainParams
  | SetAdmin of address
  | WithdrawReserve of mainParams
  | AddMarket of newMarketParams
  | SetTokenFactors of setTokenParams
  | SetGlobalFactors of setGlobalParams
  | Use of useAction

// yToken
type return is list (operation) * tokenStorage
type tokenFunc is (tokenAction * tokenStorage) -> return
type useFunc is (useAction * tokenStorage * address) -> return
type useParam is useAction

type fullTokenStorage   is record [
  storage               : tokenStorage;
  tokenLambdas          : big_map(nat, tokenFunc);
  useLambdas            : big_map(nat, useFunc);
]

type fullReturn is list (operation) * fullTokenStorage

//Proxy

type getType is Get of string * contract(oracleParam)

type proxyReturn is list (operation) * proxyStorage
type proxyFunc is (proxyAction * proxyStorage * address) -> proxyReturn

type setProxyParams is record [
  index                 : nat;
  func                  : proxyFunc;
]

type entryProxyAction   is
| ProxyUse of proxyAction
| SetProxyAction of setProxyParams

type fullProxyStorage   is record [
  storage               : proxyStorage;
  proxyLambdas          : big_map(nat, proxyFunc);
]

type fullProxyReturn is list (operation) * fullProxyStorage

// interestRate
type entryRateAction is RateUse of rateAction

type rateReturn is list (operation) * rateStorage
type rateFunc is (rateAction * rateStorage * address) -> rateReturn

type fullRateStorage    is record [
  storage               : rateStorage;
  rateLambdas           : big_map(nat, rateFunc);
]

type fullRateReturn is list (operation) * fullRateStorage
