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

type collUnitsReturn  is [@layout:comb] record [
  collaterralUnits      : nat;
  interestUpdateTimes    : map(nat, timestamp);
  priceUpdateTimes       : map(nat, timestamp);
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

 const initAcc : collUnitsReturn = record [
  collaterralUnits = 0n;
  interestUpdateTimes = (map[]: map(nat, timestamp));
  priceUpdateTimes = (map[]: map(nat, timestamp))
];

[@view] function maxBorrowInCU(
  const user            : address;
  const s               : fullStorage)
                        : collUnitsReturn is
  block {
    const ledger = s.storage.ledger;
    const tokens = s.storage.tokens;
    const markets = s.storage.markets;
    function oneToken(
      var acc           : collUnitsReturn;
      const tokenId     : tokenId)
                        : collUnitsReturn is
      block {
        const userBalance : nat = getBalanceByToken(user, tokenId, ledger);
        const token : tokenType = getToken(tokenId, tokens);
        acc.interestUpdateTimes[tokenId] := token.interestUpdateTime;
        acc.priceUpdateTimes[tokenId] := token.priceUpdateTime;
        if token.totalSupplyF > 0n then {
          const liquidityF : nat = getLiquidity(token);
          (* sum += collateralFactorF * exchangeRate * oraclePrice * balance *)
          acc.collaterralUnits := acc.collaterralUnits +
              userBalance * token.lastPrice * token.collateralFactorF * liquidityF / token.totalSupplyF / precision;
        }
        else skip;
      } with acc;
  } with Set.fold(oneToken, getTokenIds(user, markets), initAcc)

[@view] function outstandingBorrowInCU(
  const user            : address;
  const s               : fullStorage)
                        : collUnitsReturn is
  block {
    const accounts = s.storage.accounts;
    const ledger = s.storage.ledger;
    const tokens = s.storage.tokens;
    const borrows = s.storage.borrows;
    function oneToken(
      var acc           : collUnitsReturn;
      var tokenId       : tokenId)
                        : collUnitsReturn is
      block {
        const userAccount : account = getAccount(user, tokenId, accounts);
        const userBalance : nat = getBalanceByToken(user, tokenId, ledger);
        var token : tokenType := getToken(tokenId, tokens);
        acc.interestUpdateTimes[tokenId] := token.interestUpdateTime;
        acc.priceUpdateTimes[tokenId] := token.priceUpdateTime;
        (* sum += oraclePrice * borrow *)
        if userBalance > 0n or userAccount.borrow > 0n
        then acc.collaterralUnits := acc.collaterralUnits + userAccount.borrow * token.lastPrice
        else skip;
      } with acc;
  } with Set.fold(oneToken, getTokenIds(user, borrows), initAcc)
