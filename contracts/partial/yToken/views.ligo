[@view] function balanceOf(
  const p               : list(balance_of_request);
  const s               : fullStorage)
                        : list(balance_of_response) is
  block {
    function lookUpBalance(
      const l           : list(balance_of_response);
      const request     : balance_of_request)
                        : list(balance_of_response) is
      block {
        require(request.token_id < s.storage.lastTokenId, Errors.FA2.undefined)
      } with record [
            request = request;
            balance = getBalanceByToken(
                request.owner,
                request.token_id,
                s.storage.ledger
              ) / precision;
          ] # l;
   } with List.fold(lookUpBalance, p, (nil: list(balance_of_response)))

function convert(
  const params          : yAssetParams;
  const lastTokenId     : nat;
  const tokens          : big_map(tokenId, tokenType);
  const toShares        : bool)
                        : nat is
  block {
    require(params.tokenId < lastTokenId, Errors.YToken.undefined);
    const token : tokenType = getToken(params.tokenId, tokens);
    const liquidityF : nat = getLiquidity(token);
    const result = if toShares
          then params.amount * token.totalSupplyF / liquidityF
          else params.amount * liquidityF / token.totalSupplyF
  } with result

[@view] function shareToToken(
  const params          : yAssetParams;
  const s               : fullStorage)
                        : nat is
  convert(
    params,
    s.storage.lastTokenId,
    s.storage.tokens,
    False
  )

[@view] function tokenToShare(
  const params          : yAssetParams;
  const s               : fullStorage)
                        : nat is
  convert(
    params,
    s.storage.lastTokenId,
    s.storage.tokens,
    True
  )