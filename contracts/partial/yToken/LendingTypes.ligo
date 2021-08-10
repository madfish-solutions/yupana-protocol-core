type totalSupplyParams is
  michelson_pair(tokenId, "tokenId", contract(nat), "")

type liquidateParams is record [
  borrowToken           : nat;
  collateralToken       : nat;
  borrower              : address;
  amount                : nat;
]

type mainParams is record [
  tokenId               : nat;
  amount                : nat;
]

type faTransferParams is [@layout:comb] record [
  [@annot:from] from_   : address;
  [@annot:to] to_       : address;
  value : nat;
]

type transferType is TransferOutside of faTransferParams

[@inline] const zeroAddress : address = (
  "tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg" : address
);
[@inline] const zeroTimestamp : timestamp = (
  "2000-01-01t10:10:10Z" : timestamp
);
const accuracy : nat = 1000000000000000000n; //1e+18
[@inline] const noOperations : list (operation) = nil;