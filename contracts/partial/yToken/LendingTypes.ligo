type assetType          is
| FA12
| FA2                     of nat

type allowanceAmount    is [@layout:comb] record [
  src                   : address;
  amount                : nat;
]

type account            is [@layout:comb] record [
  (* TODO: join the maps with token id as the key *)
  balances              : map(tokenId, nat);
  allowances            : set(address);
  borrows               : map(tokenId, nat);
  lastBorrowIndex       : map(tokenId, nat);
  markets               : set(tokenId);
]

type tokenInfo         is [@layout:comb] record [
  mainToken             : address;
  faType                : assetType;
  interstRateModel      : address;
  lastUpdateTime        : timestamp;
  priceUpdateTime       : timestamp;
  totalBorrowsFloat     : nat;
  totalLiquidFloat      : nat;
  totalSupplyFloat      : nat;
  totalReservesFloat    : nat;
  borrowIndex           : nat;
  maxBorrowRate         : nat;
  collateralFactorFloat : nat;
  reserveFactorFloat    : nat;
  lastPrice             : nat;
]

type tokenStorage       is [@layout:comb] record [
  admin                 : address;
  accountInfo           : big_map(address, account);
  tokenInfo             : big_map(tokenId, tokenInfo);
  metadata              : big_map(string, bytes);
  tokenMetadata         : big_map(tokenId, tokenMetadataInfo);
  lastTokenId           : nat;
  priceFeedProxy        : address;
  closeFactorFloat      : nat;
  liqIncentiveFloat     : nat;
  maxMarkets            : nat;
]

type tokenSet is set(tokenId)

type totalSupplyParams is [@layout:comb] record [
  token_id              : tokenId;
  [@annot:]receiver     : contract(nat);
]

type liquidateParams    is [@layout:comb] record [
  borrowToken           : nat;
  collateralToken       : nat;
  borrower              : address;
  amount                : nat;
]

type yAssetParams       is [@layout:comb] record [
  tokenId               : nat;
  amount                : nat;
]

type faTransferParams   is [@layout:comb] record [
  [@annot:from] from_   : address;
  [@annot:to] to_       : address;
  value                 : nat;
]

type setTokenParams     is [@layout:comb] record [
  tokenId               : nat;
  collateralFactorFloat : nat;
  reserveFactorFloat    : nat;
  interstRateModel      : address;
  maxBorrowRate         : nat;
]

type setGlobalParams    is [@layout:comb] record [
  closeFactorFloat      : nat;
  liqIncentiveFloat     : nat;
  priceFeedProxy        : address;
  maxMarkets            : nat;
]

type newMetadataParams  is map(string, bytes)

type setModelParams     is [@layout:comb] record [
  tokenId               : nat;
  modelAddress          : address;
]

type newMarketParams    is [@layout:comb] record [
  interstRateModel      : address;
  assetAddress          : address;
  collateralFactorFloat : nat;
  reserveFactorFloat    : nat;
  maxBorrowRate         : nat;
  tokenMetadata         : newMetadataParams;
  faType                : assetType;
]

type oracleParam is (string * (timestamp * nat))

type pairParam          is [@layout:comb] record [
  tokenId               : tokenId;
  pairName              : string;
]

type calcCollParams     is [@layout:comb] record [
  s                     : tokenStorage;
  res                   : nat;
  userAccount           : account;
]

type transferType is TransferOutside of faTransferParams
type iterTransferType is IterateTransferOutside of transferParam

type contrParam is (string * (timestamp * nat))
type updParams is (string * contract(contrParam))

[@inline] const zeroAddress : address = (
  "tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg" : address
);
[@inline] const zeroTimestamp : timestamp = (
  "2000-01-01t10:10:10Z" : timestamp
);
[@inline] const accuracy : nat = 1000000000000000000n; //1e+18
[@inline] const noOperations : list (operation) = nil;
