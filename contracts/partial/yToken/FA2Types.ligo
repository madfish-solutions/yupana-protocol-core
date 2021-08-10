type tokenId is nat

type tokenMetadataInfo is [@layout:comb] record [
  tokenId               : tokenId;
  tokenInfo            : map(string, bytes);
]

type transferDestination is [@layout:comb] record [
  to_                   : address;
  tokenId               : tokenId;
  amount                : nat;
]

type transferParam is [@layout:comb] record [
  from_                 : address;
  txs                   : list(transferDestination);
]

type transferParams is list(transferParam)

type balanceOfRequest is [@layout:comb] record [
  owner                 : address;
  tokenId               : tokenId;
]

type balanceOfResponse is [@layout:comb] record [
  request               : balanceOfRequest;
  balance               : nat;
]

type balanceParams is [@layout:comb] record [
  requests              : list(balanceOfRequest);
  callback              : contract(list(balanceOfResponse));
]

type operatorParam is [@layout:comb] record [
  owner                 : address;
  operator              : address;
  tokenId               : tokenId;
]

type updateOperatorParam is
| AddOperator        of operatorParam
| RemoveOperator     of operatorParam

type updateOperatorParams is list(updateOperatorParam)
