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
  | SetBorrowPause of borrowPauseParams

type tokenAction        is
  | ITransfer of transferParams
  | IUpdate_operators of updateOperatorParams
  | IBalance_of of balanceParams
  | IGet_total_supply of totalSupplyParams


// yToken
type return is list (operation) * yStorage
type tokenFunc is (tokenAction * yStorage) -> return
type useFunc is (useAction * yStorage) -> return
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
  | Update_operators of updateOperatorParams
  | Balance_of of balanceParams
  | Get_total_supply of totalSupplyParams
  | UpdateInterest of tokenId
  | AccrueInterest of yAssetParams
  | PriceCallback of yAssetParams
  | Use of useAction
  | SetUseAction of setUseParams
  | SetTokenAction of setUseTokenParams

type fullyStorage   is record [
  storage               : yStorage;
  tokenLambdas          : big_map(nat, bytes);
  useLambdas            : big_map(nat, bytes);
]

type fullReturn is list (operation) * fullyStorage

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
  | SetCoefficients of setCoeffParams
  | GetBorrowRate of rateParams
  | GetUtilizationRate of rateParams
  | GetSupplyRate of rateParams

type rateReturn is list (operation) * rateStorage
