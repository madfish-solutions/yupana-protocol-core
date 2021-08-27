#include "/yToken/FA2Types.ligo"
#include "/yToken/LendingTypes.ligo"
#include "/interestRate/InterestRateTypes.ligo"
#include "/proxy/PriceFeedTypes.ligo"

type useAction          is
  | Mint of mainParams
  | Redeem of mainParams
  | Borrow of mainParams
  | Repay of mainParams
  | Liquidate of liquidateParams
  | EnterMarket of tokenId
  | ExitMarket of tokenId
  (* TODO: think do we even need the method? *)
  | UpdatePrice of tokenSet

type tokenAction        is
  | ITransfer of transferParams
  | IUpdateOperators of updateOperatorParams
  | IBalanceOf of balanceParams
  | IGetTotalSupply of totalSupplyParams

type proxyAction        is
  | UpdateAdmin of address
  | UpdateOracle of address
  | UpdateYToken of address
  | UpdatePair of pairParam
  | GetPrice of tokenId
  | ReceivePrice of oracleParam

type rateAction         is
  | UpdateRateAdmin of address
  | UpdateRateYToken of address
  | SetCoefficients of setCoeffParams
  | GetBorrowRate of rateParams
  | GetUtilizationRate of rateParams
  | GetSupplyRate of rateParams
  | EnsuredSupplyRate of rateParams
  | UpdReserveFactor of nat

// yToken
type return is list (operation) * tokenStorage
type tokenFunc is (tokenAction * tokenStorage) -> return
type useFunc is (useAction * tokenStorage) -> return
type useParam is useAction

type setUseParams is record [
  index                 : nat;
  func                  : useFunc;
]

type setUseTokenParams is record [
  index                 : nat;
  func                  : tokenFunc;
]

type entryAction        is
  | Transfer of transferParams
  | UpdateOperators of updateOperatorParams
  | BalanceOf of balanceParams
  | GetTotalSupply of totalSupplyParams
  | UpdateInterest of tokenId
  | EnsuredUpdateInterest of tokenId
  | UpdateBorrowRate of mainParams
  | GetReserveFactor of tokenId
  | ReturnPrice of mainParams
  | SetAdmin of address
  | WithdrawReserve of mainParams
  | AddMarket of newMarketParams
  | SetTokenFactors of setTokenParams
  | SetGlobalFactors of setGlobalParams
  | Use of useAction
  | SetUseAction of setUseParams
  | SetTokenAction of setUseTokenParams

type fullTokenStorage   is record [
  storage               : tokenStorage;
  tokenLambdas          : big_map(nat, tokenFunc);
  useLambdas            : big_map(nat, useFunc);
]

type fullReturn is list (operation) * fullTokenStorage

//Proxy

type getType is Get of string * contract(oracleParam)

type proxyReturn is list (operation) * proxyStorage
type proxyFunc is (proxyAction * proxyStorage) -> proxyReturn

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

type rateReturn is list (operation) * rateStorage
type rateFunc is (rateAction * rateStorage) -> rateReturn

type setRateParams is record [
  index                 : nat;
  func                  : rateFunc;
]

type entryRateAction   is
| RateUse of rateAction
| SetInterestAction of setRateParams


type fullRateStorage    is record [
  storage               : rateStorage;
  rateLambdas           : big_map(nat, rateFunc);
]

type fullRateReturn is list (operation) * fullRateStorage
