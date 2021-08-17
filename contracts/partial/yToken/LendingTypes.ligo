type assetType          is
| FA12
| FA2                     of nat

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
  faType                : assetType;
  interstRateModel      : address;
  lastUpdateTime        : timestamp;
  totalBorrows          : nat;
  totalLiquid           : nat;
  totalSupply           : nat;
  totalReserves         : nat;
  borrowIndex           : nat;
  borrowRate            : nat;
  maxBorrowRate         : nat;
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

type totalSupplyParams is
  michelson_pair(tokenId, "tokenId", contract(nat), "") (* !!! naming*)

type liquidateParams    is record [
  borrowToken           : nat;
  collateralToken       : nat;
  borrower              : address;
  amount                : nat;
]

type mainParams         is record [
  tokenId               : nat;
  amount                : nat;
]

type faTransferParams   is [@layout:comb] record [
  [@annot:from] from_   : address;
  [@annot:to] to_       : address;
  value                 : nat;
]

type setTokenParams     is record [
  tokenId               : nat;
  collateralFactor      : nat;
  reserveFactor         : nat;
  interstRateModel      : address;
  maxBorrowRate         : nat;
]

type setGlobalParams    is record [
  closeFactor           : nat;
  liqIncentive          : nat;
  priceFeedProxy        : address;
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
  maxBorrowRate         : nat;
  tokenMetadata         : newMetadataParams;
  faType                : assetType;
]

type oracleParam is (string * (timestamp * nat))

type pairParam          is record [
  tokenId               : tokenId;
  pairName              : string;
]

type calcCollParams     is [@layout:comb] record [
  s                     : tokenStorage;
  res                   : nat;
  userAccount           : account;
]

type oneTokenUpdParam   is [@layout:comb] record [
  operations            : list (operation);
  priceFeedProxy        : address;
]

type transferType is TransferOutside of faTransferParams
type iterTransferType is IterateTransferOutside of transferParam

type contrParam is (string * (timestamp * nat))
type updParams is (string * contract(contrParam))

[@inline] const maxMarkets : nat = 10n;
[@inline] const zeroAddress : address = (
  "tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg" : address
);
[@inline] const zeroTimestamp : timestamp = (
  "2000-01-01t10:10:10Z" : timestamp
);
[@inline] const accuracy : nat = 1000000000000000000n; //1e+18
[@inline] const noOperations : list (operation) = nil;
