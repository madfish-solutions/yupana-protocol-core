#include "./FA2Types.ligo"
#include "./LendingTypes.ligo"

type allowanceAmount    is [@layout:comb] record [
  src                   : address;
  amount                : nat;
]

type account            is [@layout:comb] record [
  balances              : map(tokenId, nat); // in yToken
  allowances            : set(address);
  borrowAmount          : map(tokenId, nat); // in asset
  lastBorrowIndex       : map(tokenId, nat);
  markets               : set(tokenId);
]

type tokenInfo         is [@layout:comb] record [
  mainToken             : address;
  interstRateModel      : address;
  lastUpdateTime        : timestamp;
  totalBorrows          : nat;
  totalLiquid           : nat;
  totalSupply           : nat;
  totalReserves         : nat;
  borrowIndex           : nat;
  collateralFactor      : nat;
  reserveFactor         : nat;
  lastPrice             : nat;
  exchangeRate          : nat;
]

type tokenStorage       is [@layout:comb] record [
  admin                 : address;
  accountInfo           : big_map(address, account);
  tokenInfo             : big_map(tokenId, tokenInfo);
  metadata              : big_map(string, bytes);
  tokenMetadata         : big_map(tokenId, tokenMetadataInfo);
  lastTokenId           : nat;
  priceFeedProxy        : address;
  closeFactor           : nat;
  liqIncentive          : nat;
]

type newMetadataParams  is map(string, bytes)

type setModelParams     is record [
  tokenId               : nat;
  modelAddress          : address;
]

type newMarketParams     is record [
  interstRateModel      : address;
  assetAddress          : address;
  collateralFactor      : nat;
  reserveFactor         : nat;
  tokenMetadata         : newMetadataParams;
]

type oracleParam is (string * (timestamp * nat))

type pairParam          is record [
  tokenId               : tokenId;
  pairName              : string;
]

type useAction          is
  | Mint of mainParams
  | Redeem of mainParams
  | Borrow of mainParams
  | EnsuredBorrow of mainParams
  | Repay of mainParams
  | Liquidate of liquidateParams
  | EnsuredLiquidate of liquidateParams
  | SetAdmin of address
  | WithdrawReserve of mainParams
  | AddMarket of newMarketParams
  | SetTokenFactors of setTokenParams
  | SetGlobalFactors of setGlobalParams
  | EnterMarket of tokenId
  | ExitMarket of tokenId
  | EnsuredExitMarket of tokenId
  | UpdatePrice of mainParams

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

type entryAction        is
  | Transfer of transferParams
  | UpdateOperators of updateOperatorParams
  | BalanceOf of balanceParams
  | GetTotalSupply of totalSupplyParams
  | Use of useAction

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

type contrParam is (string * (timestamp * nat))
type updParams is (string * contract(contrParam))

const maxMarkets : nat = 10n;

type calcCollParams     is [@layout:comb] record [
  s                     : tokenStorage;
  res                   : nat;
  userAccount           : account;
]

type oneTokenUpdParam   is [@layout:comb] record [
  operations            : list (operation);
  priceFeedProxy        : address;
]
