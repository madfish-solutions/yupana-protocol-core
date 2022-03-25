#include "/yToken/fa2Types.ligo"
#include "/yToken/lendingTypes.ligo"
#include "/interestRate/interestRateTypes.ligo"
#include "/proxy/priceFeedTypes.ligo"

type useAction          is
  | Mint of yAssetParamsWithMR
  | Redeem of yAssetParamsWithMR
  | Borrow of yAssetParamsWithDL
  | Repay of yAssetParamsWithDL
  | Liquidate of liquidateParams
  | EnterMarket of tokenId
  | ExitMarket of tokenId
  | SetAdmin of address
  | WithdrawReserve of yAssetParams
  | SetTokenFactors of setTokenParams
  | SetGlobalFactors of setGlobalParams
  | SetBorrowPause of borrowPauseParams
  | ApproveAdmin of unit

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
  | AddMarket of newMarketParams
  | UpdateMetadata of updateMetadataParams
  | Use of useAction
  | SetUseAction of setUseParams
  | SetTokenAction of setUseTokenParams

type fullStorage   is record [
  storage               : yStorage;
  metadata              : big_map(string, bytes);
  token_metadata        : big_map(tokenId, token_metadata_info);
  tokenLambdas          : big_map(nat, bytes);
  useLambdas            : big_map(nat, bytes);
]

type fullReturn is list (operation) * fullStorage

//Proxy
type getType is Get of string * contract(oracleParam)

type proxyReturn is list (operation) * proxyStorage

type entryProxyAction   is
  | SetProxyAdmin of address
  | SetTimeLimit of nat
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
