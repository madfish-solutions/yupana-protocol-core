type balanceOfParams  is [@layout:comb] record [
  requests              : list(balance_of_request);
  precision             : bool;
]

type convertParams    is [@layout:comb] record [
  toShares              : bool;
  tokenId               : nat;
  amount                : nat;
  precision             : bool;
]

[@view] function balanceOf(
  const p               : balanceOfParams;
  const s               : fullStorage)
                        : list(balance_of_response) is
  block {
    function lookUpBalance(
      const request     : balance_of_request)
                        : balance_of_response is
      block {
        require(request.token_id < s.storage.lastTokenId, Errors.FA2.undefined);
        const userBalance = getBalanceByToken(
            request.owner,
            request.token_id,
            s.storage.ledger
          );
      } with record [
            request = request;
            balance = if p.precision
                      then userBalance / precision
                      else userBalance;
          ];
   } with List.map(lookUpBalance, p.requests)

function convert(
  const params          : convertParams;
  const s               : fullStorage)
                        : nat is
  block {
    require(params.tokenId < s.storage.lastTokenId, Errors.YToken.undefined);
    const token : tokenType = getToken(params.tokenId, s.storage.tokens);
    const liquidityF : nat = getLiquidity(token);
    var result := params.amount;
    if params.toShares
      then {
        if params.precision
        then result := result * precision
        else skip;

        result := if liquidityF > 0n
          then result * token.totalSupplyF / liquidityF
          else 0n;
      }
      else {
        result := if token.totalSupplyF > 0n
          then result * liquidityF / token.totalSupplyF
          else 0n;

        if params.precision
        then result := result / precision
        else skip;
      }
  } with result