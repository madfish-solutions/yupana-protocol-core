#include "/yToken/fa2Types.ligo"
#include "/yToken/lendingTypes.ligo"
#include "/interestRate/interestRateTypes.ligo"
#include "/proxy/priceFeedTypes.ligo"

type useAction          is
  | Mint of yAssetParams
  | Redeem of yAssetParams
  | Borrow of yAssetParams
  | Repay of yAssetParams
  | Liquidate of liquidateParams
  | EnterMarket of tokenId
  | ExitMarket of tokenId
  | SetAdmin of address
  | WithdrawReserve of yAssetParams
  | AddMarket of newMarketParams
  | UpdateMetadata of updateMetadataParams
  | SetTokenFactors of setTokenParams
  | SetGlobalFactors of setGlobalParams

type tokenAction        is
  | ITransfer of transferParams
  | IUpdateOperators of updateOperatorParams
  | IBalanceOf of balanceParams
  | IGetTotalSupply of totalSupplyParams


// yToken
type return is list (operation) * tokenStorage
type tokenFunc is (tokenAction * tokenStorage) -> return
type useFunc is (useAction * tokenStorage) -> return
type useParam is useAction

type setUseParams       is record [
  index                 : nat;
  func                  : bytes;
]

type setUseTokenParams  is record [
  index                 : nat;
  func                  : bytes;
]

type entryAction        is
  | Transfer of transferParams
  | UpdateOperators of updateOperatorParams
  | BalanceOf of balanceParams
  | GetTotalSupply of totalSupplyParams
  | UpdateInterest of tokenId
  | AccrueInterest of yAssetParams
  | GetReserveFactor of tokenId
  | ReturnPrice of yAssetParams
  | Use of useAction
  | SetUseAction of setUseParams
  | SetTokenAction of setUseTokenParams

type fullTokenStorage   is record [
  storage               : tokenStorage;
  tokenLambdas          : big_map(nat, bytes);
  useLambdas            : big_map(nat, bytes);
]

type fullReturn is list (operation) * fullTokenStorage

//Proxy
type getType is Get of string * contract(oracleParam)

type proxyReturn is list (operation) * proxyStorage

type entryProxyAction   is
  | SetProxyAdmin of address
  | UpdateOracle of address
  | UpdateYToken of address
  | UpdatePair of pairParam
  | GetPrice of tokenSet
  | ReceivePrice of oracleParam

// interestRate
type entryRateAction   is
  | UpdateAdmin of address
  | SetYToken of address
  | SetCoefficients of setCoeffParams
  | GetBorrowRate of rateParams
  | GetUtilizationRate of rateParams
  | GetSupplyRate of rateParams
  | UpdReserveFactor of nat

type rateReturn is list (operation) * rateStorage
