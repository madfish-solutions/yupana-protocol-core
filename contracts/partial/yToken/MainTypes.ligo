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
  owner                 : address;
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

type useAction          is
  | Mint of mainParams
  | Redeem of mainParams
  | Borrow of mainParams
  | Repay of mainParams
  | Liquidate of liquidateParams
  | SetAdmin of address
  | SetOwner of address
  | WithdrawReserve of mainParams
  | AddMarket of newMarketParams
  | SetCollaterallFactor of mainParams
  | SetReserveFactor of mainParams
  | SetModel of setModelParams
  | SetCloseFactor of nat
  | SetLiquidationIncentive of nat
  | SetProxyAddress of address
  | EnterMarket of tokenId
  | ExitMarket of tokenId


type tokenAction        is
  | ITransfer of transferParams
  | IUpdateOperators of updateOperatorParams
  | IBalanceOf of balanceParams
  | IGetTotalSupply of totalSupplyParams

type entryAction        is
  | Transfer of transferParams
  | UpdateOperators of updateOperatorParams
  | BalanceOf of balanceParams
  | GetTotalSupply of totalSupplyParams
  | Use of useAction

type return is list (operation) * tokenStorage
type tokenFunc is (tokenAction * tokenStorage) -> return
type useFunc is (useAction * tokenStorage * address) -> return

type fullTokenStorage   is record [
  storage               : tokenStorage;
  tokenLambdas          : big_map(nat, tokenFunc);
  useLambdas            : big_map(nat, useFunc);
]

type fullReturn is list (operation) * fullTokenStorage

const maxMarkets : nat = 10n;

type prms is [@layout:comb] record [
  s   : tokenStorage;
  res : nat;
  userAccount   : account;
]
