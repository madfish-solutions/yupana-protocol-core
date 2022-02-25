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

type tokenType          is [@layout:comb] record [
  mainToken             : assetType;
  interestRateModel     : address;
  interestUpdateTime    : timestamp;
  priceUpdateTime       : timestamp;
  totalBorrowsF         : nat;
  totalLiquidF          : nat;
  totalSupplyF          : nat;
  totalReservesF        : nat;
  borrowIndex           : nat;
  maxBorrowRate         : nat;
  collateralFactorF     : nat;
  liquidReserveRateF    : nat;
  reserveFactorF        : nat;
  lastPrice             : nat;
  borrowPause           : bool;
  isInterestUpdating    : bool;
  threshold             : nat;
]

type yStorage           is [@layout:comb] record [
  admin                 : address;
  ledger                : big_map((address * tokenId), nat);
  accounts              : big_map((address * tokenId), account);
  tokens                : map(tokenId, tokenType);
  lastTokenId           : nat;
  priceFeedProxy        : address;
  closeFactorF          : nat;
  liqIncentiveF         : nat;
  markets               : big_map(address, set(tokenId));
  borrows               : big_map(address, set(tokenId));
  maxMarkets            : nat;
  assets                : big_map(assetType, tokenId);
]

type tokenSet is set(tokenId)

type accountsMapType is big_map((address * tokenId), account);

type totalSupplyParams  is [@layout:comb] record [
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

type fa12TransferParams   is [@layout:comb] record [
  [@annot:] from_         : address;
  [@annot:] to_           : address;
  [@annot:] value         : nat;
]


type fa2TransferDestination is [@layout:comb] record [
  [@annot:]to_                   : address;
  [@annot:]token_id              : tokenId;
  [@annot:]amount                : nat;
]

type fa2TransferParam is [@layout:comb] record [
  [@annot:]from_                 : address;
  [@annot:]txs                   : list(fa2TransferDestination);
]

type fa2TransferParams   is list(fa2TransferParam)

type setTokenParams     is [@layout:comb] record [
  tokenId               : nat;
  collateralFactorF     : nat;
  reserveFactorF        : nat;
  interestRateModel     : address;
  maxBorrowRate         : nat;
  threshold             : nat;
  liquidReserveRateF    : nat;
]

type setGlobalParams    is [@layout:comb] record [
  closeFactorF          : nat;
  liqIncentiveF         : nat;
  priceFeedProxy        : address;
  maxMarkets            : nat;
]

type borrowPauseParams  is [@layout:comb] record [
  tokenId               : nat;
  condition             : bool;
]

type newMetadataParams is map(string, bytes)

type updateMetadataParams is [@layout:comb] record [
  tokenId               : nat;
  token_metadata        : newMetadataParams;
]

type setModelParams     is [@layout:comb] record [
  tokenId               : nat;
  modelAddress          : address;
]

type newMarketParams    is [@layout:comb] record [
  interestRateModel     : address;
  asset                 : assetType;
  collateralFactorF     : nat;
  reserveFactorF        : nat;
  maxBorrowRate         : nat;
  token_metadata        : newMetadataParams;
  threshold             : nat;
  liquidReserveRateF    : nat;
]

type oracleParam        is (string * (timestamp * nat))

type pairParam          is [@layout:comb] record [
  tokenId               : tokenId;
  pairName              : string;
  decimals              : nat;
]

type calculateCollParams is [@layout:comb] record [
  s                     : yStorage;
  user                  : address;
  res                   : nat;
]

type transferType is TransferOutside of fa12TransferParams
type iterTransferType is FA2TransferOutside of fa2TransferParams

[@inline] const zeroAddress : address = ("tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg" : address);
[@inline] const zeroTimestamp : timestamp = (0 : timestamp);
[@inline] const precision : nat = 1000000000000000000n; //1e+18
[@inline] const noOperations : list (operation) = nil;
