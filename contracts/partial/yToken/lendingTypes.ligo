type assetType          is
| FA12 of address
| FA2  of (address * nat)

type allowanceAmount    is [@layout:comb] record [
  src                   : address;
  amount                : nat;
]

type account            is [@layout:comb] record [
  allowances            : set(address);
  borrow                : nat;
  lastBorrowIndex       : nat;
]

type tokenInfo         is [@layout:comb] record [
  mainToken             : assetType;
  interestRateModel     : address;
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
  borrowPause           : bool;
]

type tokenStorage       is [@layout:comb] record [
  admin                 : address;
  ledger                : big_map((address * tokenId), nat);
  accountInfo           : big_map((address * tokenId), account);
  tokenInfo             : map(tokenId, tokenInfo);
  metadata              : big_map(string, bytes);
  tokenMetadata         : big_map(tokenId, tokenMetadataInfo);
  lastTokenId           : nat;
  priceFeedProxy        : address;
  closeFactorFloat      : nat;
  liqIncentiveFloat     : nat;
  markets               : big_map(address, set(tokenId));
  maxMarkets            : nat;
  typesInfo             : big_map(assetType, tokenId);
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
  interestRateModel     : address;
  maxBorrowRate         : nat;
]

type setGlobalParams    is [@layout:comb] record [
  closeFactorFloat      : nat;
  liqIncentiveFloat     : nat;
  priceFeedProxy        : address;
  maxMarkets            : nat;
]

type borrowPauseParams is [@layout:comb] record [
  tokenId               : nat;
  condition             : bool;
]

type newMetadataParams  is map(string, bytes)

type updateMetadataParams is [@layout:comb] record [
  tokenId               : nat;
  tokenMetadata         : newMetadataParams;
]

type setModelParams     is [@layout:comb] record [
  tokenId               : nat;
  modelAddress          : address;
]

type newMarketParams    is [@layout:comb] record [
  interestRateModel     : address;
  assetAddress          : assetType;
  collateralFactorFloat : nat;
  reserveFactorFloat    : nat;
  maxBorrowRate         : nat;
  tokenMetadata         : newMetadataParams;
]

type oracleParam is (string * (timestamp * nat))

type pairParam          is [@layout:comb] record [
  tokenId               : tokenId;
  pairName              : string;
]

type calculateCollParams is [@layout:comb] record [
  s                     : tokenStorage;
  user                  : address;
  res                   : nat;
]

type transferType is TransferOutside of faTransferParams
type iterTransferType is IterateTransferOutside of transferParams

[@inline] const zeroAddress : address = (
  "tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg" : address
);
[@inline] const zeroTimestamp : timestamp = (0 : timestamp);
[@inline] const precision : nat = 1000000000000000000n; //1e+18
[@inline] const noOperations : list (operation) = nil;
