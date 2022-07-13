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

type convertReturn    is [@layout:comb] record [
  amount                : nat;
  interestUpdateTime    : timestamp;
  priceUpdateTime       : timestamp;
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

[@view] function convert(
  const params          : convertParams;
  const s               : fullStorage)
                        : convertReturn is
  block {
    require(params.tokenId < s.storage.lastTokenId, Errors.YToken.undefined);
    const token : tokenType = getToken(params.tokenId, s.storage.tokens);
    const liquidityF : nat = getLiquidity(token);
    var value := params.amount;
    if params.toShares
      then {
        if params.precision
        then value := value * precision
        else skip;

        value := if liquidityF > 0n
          then value * token.totalSupplyF / liquidityF
          else 0n;
      }
      else {
        value := if token.totalSupplyF > 0n
          then value * liquidityF / token.totalSupplyF
          else 0n;

        if params.precision
        then value := value / precision
        else skip;
      };
    const result : convertReturn = record [
      amount = value;
      interestUpdateTime = token.interestUpdateTime;
      priceUpdateTime = token.priceUpdateTime
    ];
  } with result

