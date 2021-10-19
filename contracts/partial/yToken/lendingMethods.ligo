#include "./fa2Methods.ligo"
#include "./common.ligo"
#include "./adminMethods.ligo"

function ensureNotZero(
  const amt             : nat)
                        : unit is
    if amt = 0n
    then failwith("yToken/amount-is-zero");
    else unit

[@inline] function getReserveFactorContract(
  const rateAddress     : address)
                        : contract(entryRateAction) is
  case(
    Tezos.get_entrypoint_opt("%updReserveFactor", rateAddress)
                        : option(contract(entryRateAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("yToken/cant-get-interestRate-contract(rateUse)")
        : contract(entryRateAction)
    )
  end;

[@inline] function getUpdateBorrowRateContract(
  const selfAddress     : address)
                        : contract(yAssetParams) is
  case(
    Tezos.get_entrypoint_opt("%accrueInterest", selfAddress)
                        : option(contract(yAssetParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("yToken/cant-get-borrowRate") : contract(yAssetParams)
    )
  end;

[@inline] function getBorrowRateContract(
  const rateAddress     : address)
                        : contract(rateParams) is
  case(
    Tezos.get_entrypoint_opt("%getBorrowRate", rateAddress)
                        : option(contract(rateParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("yToken/cant-get-interestRate-contract(getBorrowRate)")
        : contract(rateParams)
    )
  end;

[@inline] function ceil_div(
  const numerator       : nat;
  const denominator     : nat)
                        : nat is
  case ediv(numerator, denominator) of
    Some(result) -> if result.1 > 0n
      then result.0 + 1n
      else result.0
  | None -> failwith("ceil-div-error")
  end;

function verifyTokenUpdated(
    const token         : tokenInfo)
                        : unit is
    if token.lastUpdateTime < Tezos.now or token.priceUpdateTime < Tezos.now
    then failwith("yToken/need-update")
    else unit;

function calcMaxCollaterallInCU(
  const userAccount     : account;
  var params            : calculateCollParams)
                        : nat is
  block {
    function oneToken(
      var param         : calculateCollParams;
      const tokenId     : tokenId)
                        : calculateCollParams is
      block {
        const userInfo : nat = getBalanceByToken(Tezos.sender, tokenId, param.s);
        const token : tokenInfo = getTokenInfo(tokenId, param.s);

        verifyTokenUpdated(token);

        (* sum += collateralFactorFloat * exchangeRate * oraclePrice * balance *)
        param.res := param.res + ((userInfo * token.lastPrice
          * token.collateralFactorFloat) * (abs(token.totalLiquidFloat
          + token.totalBorrowsFloat - token.totalReservesFloat)
          / token.totalSupplyFloat) / precision);
      } with param;
    const result : calculateCollParams = Set.fold(
      oneToken,
      userAccount.markets,
      params
    );
  } with result.res

function calcOutstandingBorrowInCU(
  var tokenInfo         : map(tokenId, tokenInfo);
  var params            : calculateCollParams)
                        : nat is
  block {
    function oneToken(
      var param         : calculateCollParams;
      var _tokenInfo    : (tokenId * tokenInfo))
                        : calculateCollParams is
      block {
        const token : tokenInfo = getTokenInfo(param.tokenId, param.s);
        var userAccount : account := getAccount(param.user, param.tokenId, param.s);
        verifyTokenUpdated(token);

        (* sum += oraclePrice * borrow *)
        param.res := param.res + ((userAccount.borrow * token.lastPrice));
      } with param;
    const result : calculateCollParams = Map.fold(
      oneToken,
      tokenInfo,
      params
    );
  } with result.res

function updateInterest(
  const tokenId         : nat;
  var s                 : fullTokenStorage)
                        : fullReturn is
    block {
      var _token : tokenInfo := getTokenInfo(tokenId, s.storage);
      var operations : list(operation) := list[];

      if tokenId < s.storage.lastTokenId
      then skip
      else failwith("yToken/yToken-undefined");

      if _token.totalBorrowsFloat = 0n
      then block {
        _token.lastUpdateTime := Tezos.now;
        s.storage.tokenInfo[tokenId] := _token;
      }
      else operations := list[
        Tezos.transaction(
          record[
            tokenId = tokenId;
            borrowsFloat = _token.totalBorrowsFloat;
            cashFloat = _token.totalLiquidFloat;
            reservesFloat = _token.totalReservesFloat;
            precision = precision;
            contract = getUpdateBorrowRateContract(Tezos.self_address);
          ],
          0mutez,
          getBorrowRateContract(_token.interestRateModel)
        )];
    } with (operations, s)

function mint(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Mint(yAssetParams) -> {
          ensureNotZero(yAssetParams.amount);

          if yAssetParams.tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

          var mintTokensFloat : nat := yAssetParams.amount * precision;
          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s);

          if token.totalSupplyFloat =/= 0n
          then {
            verifyTokenUpdated(token);
            mintTokensFloat := mintTokensFloat * token.totalSupplyFloat /
              abs(token.totalLiquidFloat + token.totalBorrowsFloat
                - token.totalReservesFloat);
          } else skip;

          var userAccount : account := getAccount(Tezos.sender, yAssetParams.tokenId, s);
          var userInfo : nat := getBalanceByToken(Tezos.sender, yAssetParams.tokenId, s);
          // var userInfo : balanceInfo := getMapInfo(
          //   userAccount.balances,
          //   yAssetParams.tokenId
          // );

          userInfo := userInfo + mintTokensFloat;

          s.ledger[(Tezos.sender, yAssetParams.tokenId)] := userInfo;
          s.accountInfo[(Tezos.sender, yAssetParams.tokenId)] := userAccount;
          token.totalSupplyFloat := token.totalSupplyFloat + mintTokensFloat;
          token.totalLiquidFloat := token.totalLiquidFloat
            + yAssetParams.amount * precision;
          s.tokenInfo[yAssetParams.tokenId] := token;

          operations := transfer_token(Tezos.sender, Tezos.self_address, yAssetParams.amount, token.mainToken);
        }
      | _                         -> skip
      end
  } with (operations, s)

function redeem(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Redeem(yAssetParams) -> {
          if yAssetParams.tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s);

          verifyTokenUpdated(token);

          var userAccount : account := getAccount(Tezos.sender, yAssetParams.tokenId, s);

          if Set.mem(yAssetParams.tokenId, userAccount.markets)
          then failwith("yToken/token-taken-as-collateral")
          else skip;

          // var userInfo : balanceInfo := getMapInfo(
          //   userAccount.balances,
          //   yAssetParams.tokenId
          // );

          var userInfo : nat := getBalanceByToken(Tezos.sender, yAssetParams.tokenId, s);

          const liquidityFloat : nat = abs(token.totalLiquidFloat
            + token.totalBorrowsFloat - token.totalReservesFloat);

          const redeemAmount : nat = if yAssetParams.amount = 0n
          then userInfo * liquidityFloat / token.totalSupplyFloat / precision
          else yAssetParams.amount;

          s.lastTokenId := redeemAmount;

          if redeemAmount * precision > token.totalLiquidFloat
          then failwith("yToken/not-enough-liquid")
          else skip;

          var burnTokensFloat : nat := redeemAmount * precision *
            token.totalSupplyFloat / liquidityFloat;
          if userInfo < burnTokensFloat
          then failwith("yToken/not-enough-tokens-to-burn")
          else skip;

          s.maxMarkets := burnTokensFloat;

          userInfo := abs(userInfo - burnTokensFloat);
          s.ledger[(Tezos.sender, yAssetParams.tokenId)] := userInfo;
          s.accountInfo[(Tezos.sender, yAssetParams.tokenId)] := userAccount;
          token.totalSupplyFloat := abs(token.totalSupplyFloat - burnTokensFloat);
          token.totalLiquidFloat := abs(token.totalLiquidFloat - redeemAmount *
            precision);
          s.tokenInfo[yAssetParams.tokenId] := token;

          operations := transfer_token(Tezos.self_address, Tezos.sender, redeemAmount, token.mainToken);
        }
      | _               -> skip
      end
  } with (operations, s)

function borrow(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Borrow(yAssetParams) -> {
          ensureNotZero(yAssetParams.amount);

          if yAssetParams.tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

          var userAccount : account := getAccount(Tezos.sender, yAssetParams.tokenId, s);
          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s);
          verifyTokenUpdated(token);

          if token.borrowPause
          then failwith("yToken/forbidden-for-borrow");
          else skip;

          const borrowsFloat : nat = yAssetParams.amount * precision;

          if borrowsFloat > token.totalLiquidFloat
          then failwith("yToken/amount-too-big")
          else skip;


          // var userInfo : balanceInfo := getMapInfo(
          //   userAccount.balances,
          //   yAssetParams.tokenId
          // );

          if userAccount.lastBorrowIndex =/= 0n
          then userAccount.borrow := userAccount.borrow *
              token.borrowIndex / userAccount.lastBorrowIndex;
          else skip;

          userAccount.lastBorrowIndex := token.borrowIndex;

          userAccount.borrow := userAccount.borrow + borrowsFloat;
          s.accountInfo[(Tezos.sender, yAssetParams.tokenId)] := userAccount;

          const maxBorrowInCU : nat = calcMaxCollaterallInCU(
            userAccount,
            record[s = s; user = Tezos.sender; res = 0n; tokenId = yAssetParams.tokenId]
          );
          const outstandingBorrowInCU : nat = calcOutstandingBorrowInCU(
            s.tokenInfo,
            record[s = s; user = Tezos.sender; res = 0n; tokenId = yAssetParams.tokenId]
          );

          if outstandingBorrowInCU > maxBorrowInCU
          then failwith("yToken/exceeds-the-permissible-debt");
          else skip;

          token.totalBorrowsFloat := token.totalBorrowsFloat + borrowsFloat;
          token.totalLiquidFloat := abs(token.totalLiquidFloat - borrowsFloat);
          s.tokenInfo[yAssetParams.tokenId] := token;

          operations := transfer_token(Tezos.self_address, Tezos.sender, yAssetParams.amount, token.mainToken);
        }
      | _                         -> skip
      end
  } with (operations, s)

function repay (
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Repay(yAssetParams) -> {
          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s);

          if yAssetParams.tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

          verifyTokenUpdated(token);

          var repayAmountFloat : nat := yAssetParams.amount * precision;

          var userAccount : account := getAccount(Tezos.sender, yAssetParams.tokenId, s);
          // var userInfo : balanceInfo := getMapInfo(
          //   userAccount.balances,
          //   yAssetParams.tokenId
          // );

          if userAccount.lastBorrowIndex =/= 0n
          then userAccount.borrow := userAccount.borrow *
            token.borrowIndex / userAccount.lastBorrowIndex;
          else skip;

          if repayAmountFloat = 0n
          then repayAmountFloat := userAccount.borrow;
          else skip;

          if repayAmountFloat > userAccount.borrow
          then failwith("yToken/amount-should-be-less-or-equal")
          else skip;

          userAccount.borrow := abs(
            userAccount.borrow - repayAmountFloat
          );

          userAccount.lastBorrowIndex := token.borrowIndex;
          s.accountInfo[(Tezos.sender, yAssetParams.tokenId)] := userAccount;
          token.totalBorrowsFloat := abs(token.totalBorrowsFloat
            - repayAmountFloat);
          token.totalLiquidFloat := token.totalLiquidFloat + repayAmountFloat;
          s.tokenInfo[yAssetParams.tokenId] := token;

          var value : nat := ceil_div(repayAmountFloat, precision);
          operations := transfer_token(Tezos.sender, Tezos.self_address, value, token.mainToken);
        }
      | _                         -> skip
      end
  } with (operations, s)

function liquidate(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Liquidate(params) -> {
          ensureNotZero(params.amount);

          if params.borrowToken < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined(borrowToken)");

          if params.collateralToken < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined(collateralToken)");

          var borrowerAccount : account := getAccount(
            params.borrower,
            params.borrowToken,
            s
          );
          var borrowToken : tokenInfo := getTokenInfo(
            params.borrowToken,
            s
          );

          verifyTokenUpdated(borrowToken);

          if Tezos.sender = params.borrower
          then failwith("yToken/borrower-cannot-be-liquidator")
          else skip;

          // var borrowerInfo : balanceInfo := getMapInfo(
          //   borrowerAccount.balances,
          //   params.borrowToken
          // );

          const maxBorrowInCU : nat = calcMaxCollaterallInCU(
            borrowerAccount,
            record[s = s; user = params.borrower; res = 0n; tokenId = params.borrowToken]
          );
          const outstandingBorrowInCU : nat = calcOutstandingBorrowInCU(
            s.tokenInfo,
            record[s = s; user = params.borrower; res = 0n; tokenId = params.borrowToken]
          );

          if outstandingBorrowInCU > maxBorrowInCU
          then skip
          else failwith("yToken/liquidation-not-achieved");
          if borrowerAccount.borrow = 0n
          then failwith("yToken/debt-is-zero");
          else skip;

          var liqAmountFloat : nat := params.amount * precision;

          if borrowerAccount.lastBorrowIndex =/= 0n
          then borrowerAccount.borrow := borrowerAccount.borrow *
            borrowToken.borrowIndex /
            borrowerAccount.lastBorrowIndex;
          else skip;

          (* liquidate amount can't be more than allowed close factor *)
          const maxClose : nat = borrowerAccount.borrow * s.closeFactorFloat
            / precision;

          if liqAmountFloat <= maxClose
          then skip
          else failwith("yToken/too-much-repay");

          borrowerAccount.borrow := abs(
            borrowerAccount.borrow - liqAmountFloat
          );
          borrowerAccount.lastBorrowIndex := borrowToken.borrowIndex;
          borrowToken.totalBorrowsFloat := abs(
            borrowToken.totalBorrowsFloat - liqAmountFloat
          );
          borrowToken.totalLiquidFloat := borrowToken.totalLiquidFloat + liqAmountFloat;

          operations := transfer_token(Tezos.sender, Tezos.self_address, params.amount, borrowToken.mainToken);

          if borrowerAccount.markets contains params.collateralToken
          then skip
          else failwith("yToken/collateralToken-not-contains-in-borrow-market");

          var collateralToken : tokenInfo := getTokenInfo(
            params.collateralToken,
            s
          );

          verifyTokenUpdated(collateralToken);

          (* seizeAmount = actualRepayAmount * liquidationIncentive
            * priceBorrowed / priceCollateral
            seizeTokens = seizeAmount / exchangeRate
          *)
          const seizeAmount : nat = liqAmountFloat * s.liqIncentiveFloat
            * borrowToken.lastPrice * collateralToken.totalSupplyFloat;

          const exchangeRateFloat : nat = abs(
            collateralToken.totalLiquidFloat + collateralToken.totalBorrowsFloat
            - collateralToken.totalReservesFloat
          ) * precision * collateralToken.lastPrice;

          const seizeTokensFloat : nat = seizeAmount / exchangeRateFloat;

          var liquidatorAccount : account := getAccount(
            Tezos.sender,
            params.collateralToken,
            s
          );

          var borrowerCollateralInfo : nat := getBalanceByToken(params.borrower, params.collateralToken, s);

          if borrowerCollateralInfo < seizeTokensFloat
          then failwith("yToken/seize/not-enough-tokens")
          else skip;

          var liquidatorInfo : nat := getBalanceByToken(Tezos.sender, params.collateralToken, s);

          borrowerCollateralInfo := abs(borrowerCollateralInfo - seizeTokensFloat);
          liquidatorInfo := liquidatorInfo + seizeTokensFloat;

          s.ledger[(Tezos.sender, params.collateralToken)] := borrowerCollateralInfo;
          s.ledger[(Tezos.sender, params.collateralToken)] := liquidatorInfo;
          s.accountInfo[(params.borrower, params.borrowToken)] := borrowerAccount;
          s.accountInfo[(Tezos.sender, params.borrowToken)] := liquidatorAccount;
          s.tokenInfo[params.collateralToken] := collateralToken;
        }
      | _                         -> skip
      end
  } with (operations, s)

function enterMarket(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    case p of
      EnterMarket(tokenId) -> {
        var userAccount : account := getAccount(Tezos.sender, tokenId, s);

        if tokenId < s.lastTokenId
        then skip
        else failwith("yToken/yToken-undefined");

        if Set.size(userAccount.markets) >= s.maxMarkets
        then failwith("yToken/max-market-limit");
        else skip;

        userAccount.markets := Set.add(tokenId, userAccount.markets);
        s.accountInfo[(Tezos.sender, tokenId)] := userAccount;
      }
    | _                         -> skip
    end
  } with (noOperations, s)

function exitMarket(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
      case p of
        ExitMarket(tokenId) -> {
          var userAccount : account := getAccount(Tezos.sender, tokenId, s);

          if tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

          const token : tokenInfo = getTokenInfo(
            tokenId,
            s
          );
          verifyTokenUpdated(token);

          userAccount.markets := Set.remove(tokenId, userAccount.markets);

          const maxBorrowInCU : nat = calcMaxCollaterallInCU(
            userAccount,
            record[s = s; user = Tezos.sender; res = 0n; tokenId = tokenId]
          );
          const outstandingBorrowInCU : nat = calcOutstandingBorrowInCU(
            s.tokenInfo,
            record[s = s; user = Tezos.sender; res = 0n; tokenId = tokenId]
          );

          if outstandingBorrowInCU <= maxBorrowInCU
          then s.accountInfo[(Tezos.sender, tokenId)] := userAccount;
          else failwith("yToken/debt-not-repaid");
        }
      | _                         -> skip
      end
  } with (noOperations, s)

function returnPrice(
  const params          : yAssetParams;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    if Tezos.sender =/= s.storage.priceFeedProxy
    then failwith("yToken/permition-error");
    else skip;

    var token : tokenInfo := getTokenInfo(
      params.tokenId,
      s.storage
    );
    token.lastPrice := params.amount;
    token.priceUpdateTime := Tezos.now;
    s.storage.tokenInfo[params.tokenId] := token;
  } with (noOperations, s)

function accrueInterest(
  const params          : yAssetParams;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {

    var token : tokenInfo := getTokenInfo(params.tokenId, s.storage);
    const borrowRate : nat = params.amount;

    if Tezos.sender =/= token.interestRateModel
    then failwith("yToken/not-self-address")
    else skip;

    if borrowRate >= token.maxBorrowRate
    then failwith("yToken/borrow-rate-is-absurdly-high");
    else skip;

    //  Calculate the number of blocks elapsed since the last accrual
    const blockDelta : nat = abs(Tezos.now - token.lastUpdateTime);

    const simpleInterestFactorFloat : nat = borrowRate * blockDelta;
    const interestAccumulatedFloat : nat = simpleInterestFactorFloat *
      token.totalBorrowsFloat / precision;

    token.totalBorrowsFloat := interestAccumulatedFloat + token.totalBorrowsFloat;
    // one mult operation with float require precision division
    token.totalReservesFloat := interestAccumulatedFloat * token.reserveFactorFloat /
      precision + token.totalReservesFloat;
    // one mult operation with float require precision division
    token.borrowIndex := simpleInterestFactorFloat * token.borrowIndex /
      precision + token.borrowIndex;
    token.lastUpdateTime := Tezos.now;

    s.storage.tokenInfo[params.tokenId] := token;
  } with (noOperations, s)

function getReserveFactor(
  const tokenId         : tokenId;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    var token : tokenInfo := getTokenInfo(tokenId, s.storage);
    const operations : list(operation) = list [
      Tezos.transaction(
        UpdReserveFactor(token.reserveFactorFloat),
        0mutez,
        getReserveFactorContract(token.interestRateModel)
      )
    ];
  } with (operations, s)
