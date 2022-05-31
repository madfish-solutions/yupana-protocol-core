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
      const l           : list(balance_of_response);
      const request     : balance_of_request)
                        : list(balance_of_response) is
      block {
        require(request.token_id < s.storage.lastTokenId, Errors.FA2.undefined);
        var userBalance := getBalanceByToken(
            request.owner,
            request.token_id,
            s.storage.ledger
          );
      } with record [
            request = request;
            balance = if p.precision
                      then userBalance / precision
                      else userBalance;
          ] # l;
   } with List.fold(lookUpBalance, p.requests, (nil: list(balance_of_response)))

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

        result := if liquidityF = 0n
          then 0n
          else result * token.totalSupplyF / liquidityF;
      }
      else {
        result := if token.totalSupplyF = 0n
          then 0n
          else result * liquidityF / token.totalSupplyF;

        if params.precision
        then result := result / precision
        else skip;
      }
  } with result