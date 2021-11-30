type tokenId is nat

type tokenMetadataInfo is [@layout:comb] record [
  token_id              : tokenId;
  tokens                : map(string, bytes);
]

type transferDestination is [@layout:comb] record [
  to_                   : address;
  token_id              : tokenId;
  amount                : nat;
]

type transferParam is [@layout:comb] record [
  from_                 : address;
  txs                   : list(transferDestination);
]

type transferParams is list(transferParam)

type balance_of_request is [@layout:comb] record [
  owner                 : address;
  token_id              : tokenId;
]

type balance_of_response is [@layout:comb] record [
  request               : balance_of_request;
  balance               : nat;
]

type balanceParams is [@layout:comb] record [
  requests              : list(balance_of_request);
  callback              : contract(list(balance_of_response));
]

type operatorParam is [@layout:comb] record [
  owner                 : address;
  operator              : address;
  token_id              : tokenId;
]

type updateOperatorParam is
| Add_operator        of operatorParam
| Remove_operator     of operatorParam

type updateOperatorParams is list(updateOperatorParam)
