#include "./fa2Methods.ligo"
#include "./wrapTransfer.ligo"
#include "./adminMethods.ligo"

function getLiquidity(
  const token           : tokenType)
                        : nat is
  case is_nat(token.totalLiquidF + token.totalBorrowsF - token.totalReservesF) of
    | None -> (failwith("underflow/liquidity - reserves") : nat)
    | Some(value) -> value
  end;

function ensureNotZero(
  const amt             : nat)
                        : unit is
    if amt = 0n
    then failwith("yToken/amount-is-zero");
    else unit

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
    const token         : tokenType)
                        : unit is
    if token.interestUpdateTime < Tezos.now or token.priceUpdateTime < Tezos.now
    then failwith("yToken/need-update")
    else unit;

function calcMaxCollateralInCU(
  const userMarkets     : set(tokenId);
  const user            : address;
  const ledger          : big_map((address * tokenId), nat);
  const tokens          : map(tokenId, tokenType))
                        : nat is
  block {
    function oneToken(
      var acc           : nat;
      const tokenId     : tokenId)
                        : nat is
      block {
        const userBalance : nat = getBalanceByToken(user, tokenId, ledger);
        const token : tokenType = getToken(tokenId, tokens);
        const liquidityF : nat = getLiquidity(token);

        (* sum += collateralFactorF * exchangeRate * oraclePrice * balance *)
        acc := acc + userBalance * token.lastPrice
          * token.collateralFactorF * liquidityF / token.totalSupplyF / precision;
      } with acc;
  } with Set.fold(oneToken, userMarkets, 0n)

function calcLiquidateCollateral(
  const userMarkets     : set(tokenId);
  const user            : address;
  const ledger          : big_map((address * tokenId), nat);
  const tokens          : map(tokenId, tokenType))
                        : nat is
  block {
    function oneToken(
      var acc           : nat;
      const tokenId     : tokenId)
                        : nat is
      block {
        const userBalance : nat = getBalanceByToken(user, tokenId, ledger);
        const token : tokenType = getToken(tokenId, tokens);
        const liquidityF : nat = getLiquidity(token);

        (* sum +=  balance * oraclePrice * exchangeRate *)
        acc := acc + userBalance * token.lastPrice * liquidityF / token.totalSupplyF;
      } with acc * token.threshold / precision;
  } with Set.fold(oneToken, userMarkets, 0n)

function applyInterestToBorrows(
  const borrowedTokens  : set(tokenId);
  const user            : address;
  const accountsMap     : accountsMapType;
  const tokensMap       : map(tokenId, tokenType))
                        : accountsMapType is
  block {
    function oneToken(
      var userAccMap    : accountsMapType;
      const tokenId     : tokenId)
                        : accountsMapType is
      block {
        var userAccount : account := getAccount(user, tokenId, accountsMap);
        const token : tokenType = getToken(tokenId, tokensMap);

        verifyTokenUpdated(token);

        if userAccount.lastBorrowIndex =/= 0n
          then userAccount.borrow := userAccount.borrow * token.borrowIndex / userAccount.lastBorrowIndex;
        else
          skip;
        userAccount.lastBorrowIndex := token.borrowIndex;
      } with Map.update((user, tokenId), Some(userAccount), userAccMap);
  } with Set.fold(oneToken, borrowedTokens, accountsMap)

function calcOutstandingBorrowInCU(
  const userBorrow      : set(tokenId);
  const user            : address;
  const accounts        : big_map((address * tokenId), account);
  const ledger          : big_map((address * tokenId), nat);
  const tokens          : map(tokenId, tokenType))
                        : nat is
  block {
    function oneToken(
      var acc           : nat;
      var tokenId       : tokenId)
                        : nat is
      block {
        const userAccount : account = getAccount(user, tokenId, accounts);
        const userBalance : nat = getBalanceByToken(user, tokenId, ledger);
        var token : tokenType := getToken(tokenId, tokens);

        (* sum += oraclePrice * borrow *)
        if userBalance > 0n or userAccount.borrow > 0n
        then acc := acc + userAccount.borrow * token.lastPrice;
        else skip;
      } with acc;
  } with Set.fold(oneToken, userBorrow, 0n)

function updateInterest(
  const tokenId         : nat;
  var s                 : fullStorage)
                        : fullReturn is
    block {
      var _token : tokenType := getToken(tokenId, s.storage.tokens);
      var operations : list(operation) := list[];

      if tokenId >= s.storage.lastTokenId
      then failwith("yToken/yToken-undefined");
      else skip;

      if _token.totalBorrowsF = 0n
      then block {
        _token.interestUpdateTime := Tezos.now;
        s.storage.tokens[tokenId] := _token;
      }
      else block {
        _token.isInterestUpdating := True;
        operations := list[
        Tezos.transaction(
          record[
            tokenId         = tokenId;
            borrowsF        = _token.totalBorrowsF;
            cashF           = _token.totalLiquidF;
            reservesF       = _token.totalReservesF;
            reserveFactorF  = _token.reserveFactorF;
            precision       = precision;
            callback        = (Tezos.self("%accrueInterest") : contract(yAssetParams));
          ],
          0mutez,
          getBorrowRateContract(_token.interestRateModel)
        )];
        s.storage.tokens[tokenId] := _token;
      }
    } with (operations, s)

function mint(
  const p               : useAction;
  var s                 : yStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Mint(yAssetParams) -> {
          ensureNotZero(yAssetParams.amount);

          if yAssetParams.tokenId >= s.lastTokenId
          then failwith("yToken/yToken-undefined");
          else skip;

          var mintTokensF : nat := yAssetParams.amount * precision;
          var token : tokenType := getToken(yAssetParams.tokenId, s.tokens);

          if token.totalSupplyF =/= 0n
          then {
            verifyTokenUpdated(token);
            const liquidityF : nat = getLiquidity(token);
            mintTokensF := mintTokensF * token.totalSupplyF / liquidityF;
          } else skip;

          var userBalance : nat := getBalanceByToken(Tezos.sender, yAssetParams.tokenId, s.ledger);
          userBalance := userBalance + mintTokensF;
          s.ledger[(Tezos.sender, yAssetParams.tokenId)] := userBalance;
          token.totalSupplyF := token.totalSupplyF + mintTokensF;
          token.totalLiquidF := token.totalLiquidF + mintTokensF;
          s.tokens[yAssetParams.tokenId] := token;
          operations := transfer_token(Tezos.sender, Tezos.self_address, yAssetParams.amount, token.mainToken);
        }
      | _                         -> skip
      end
  } with (operations, s)

function redeem(
  const p               : useAction;
  var s                 : yStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Redeem(yAssetParams) -> {
          var token : tokenType := getToken(yAssetParams.tokenId, s.tokens);
          var userBalance : nat := getBalanceByToken(Tezos.sender, yAssetParams.tokenId, s.ledger);
          const liquidityF : nat = getLiquidity(token);
          const redeemAmount : nat = if yAssetParams.amount = 0n
          then userBalance * liquidityF / token.totalSupplyF / precision
          else yAssetParams.amount;
          var burnTokensF : nat := redeemAmount * precision * token.totalSupplyF / liquidityF;

          if yAssetParams.tokenId >= s.lastTokenId
          then failwith("yToken/yToken-undefined");
          else skip;

          userBalance :=
            case is_nat(userBalance - burnTokensF) of
              | None -> (failwith("yToken/not-enough-tokens-to-burn") : nat)
              | Some(value) -> value
            end;

          s.ledger[(Tezos.sender, yAssetParams.tokenId)] := userBalance;
          token.totalSupplyF :=
            case is_nat(token.totalSupplyF - burnTokensF) of
              | None -> (failwith("underflow/totalSupplyF") : nat)
              | Some(value) -> value
            end;

          token.totalLiquidF :=
            case is_nat(token.totalLiquidF - redeemAmount * precision) of
              | None -> (failwith("underflow/totalLiquidF") : nat)
              | Some(value) -> value
            end;

          s.tokens[yAssetParams.tokenId] := token;
          s.accounts := applyInterestToBorrows(
            getTokenIds(Tezos.sender, s.borrows),
            Tezos.sender,
            s.accounts,
            s.tokens
          );

          const maxBorrowInCU : nat = calcMaxCollateralInCU(
            getTokenIds(Tezos.sender, s.markets),
            Tezos.sender,
            s.ledger,
            s.tokens
          );
          const outstandingBorrowInCU : nat = calcOutstandingBorrowInCU(
            getTokenIds(Tezos.sender, s.borrows),
            Tezos.sender,
            s.accounts,
            s.ledger,
            s.tokens
          );

          if outstandingBorrowInCU > maxBorrowInCU
          then failwith("yToken/exceeds-allowable-redeem");
          else skip;

          operations := transfer_token(Tezos.self_address, Tezos.sender, redeemAmount, token.mainToken);
        }
      | _               -> skip
      end
  } with (operations, s)

function borrow(
  const p               : useAction;
  var s                 : yStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Borrow(yAssetParams) -> {
          var token : tokenType := getToken(yAssetParams.tokenId, s.tokens);
          var borrowTokens : set(tokenId) := getTokenIds(Tezos.sender, s.borrows);
          s.accounts := applyInterestToBorrows(borrowTokens, Tezos.sender, s.accounts, s.tokens);
          var userAccount : account := getAccount(Tezos.sender, yAssetParams.tokenId, s.accounts);
          const borrowsF : nat = yAssetParams.amount * precision;

          ensureNotZero(yAssetParams.amount);

          if yAssetParams.tokenId >= s.lastTokenId
          then failwith("yToken/yToken-undefined");
          else skip;

          if token.borrowPause
          then failwith("yToken/forbidden-for-borrow");
          else skip;

          borrowTokens := Set.add(yAssetParams.tokenId, borrowTokens);
          userAccount.borrow := userAccount.borrow + borrowsF;
          s.accounts[(Tezos.sender, yAssetParams.tokenId)] := userAccount;
          s.borrows[Tezos.sender] := borrowTokens;

          const maxBorrowInCU : nat = calcMaxCollateralInCU(
            getTokenIds(Tezos.sender, s.markets),
            Tezos.sender,
            s.ledger,
            s.tokens
          );
          const outstandingBorrowInCU : nat = calcOutstandingBorrowInCU(
            getTokenIds(Tezos.sender, s.borrows),
            Tezos.sender,
            s.accounts,
            s.ledger,
            s.tokens
          );

          if outstandingBorrowInCU > maxBorrowInCU
          then failwith("yToken/exceeds-the-permissible-debt");
          else skip;

          token.totalBorrowsF := token.totalBorrowsF + borrowsF;
          token.totalLiquidF :=
            case is_nat(token.totalLiquidF - borrowsF) of
              | None -> (failwith("yToken/not-enough-liquidity") : nat)
              | Some(value) -> value
            end;
          s.tokens[yAssetParams.tokenId] := token;
          operations := transfer_token(Tezos.self_address, Tezos.sender, yAssetParams.amount, token.mainToken);
        }
      | _                         -> skip
      end
  } with (operations, s)

function repay(
  const p               : useAction;
  var s                 : yStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Repay(yAssetParams) -> {
          var token : tokenType := getToken(yAssetParams.tokenId, s.tokens);
          var borrowTokens : set(tokenId) := getTokenIds(Tezos.sender, s.borrows);
          s.accounts := applyInterestToBorrows(borrowTokens, Tezos.sender, s.accounts, s.tokens);
          var repayAmountF : nat := yAssetParams.amount * precision;
          var userAccount : account := getAccount(Tezos.sender, yAssetParams.tokenId, s.accounts);

          if yAssetParams.tokenId >= s.lastTokenId
          then failwith("yToken/yToken-undefined");
          else skip;

          if repayAmountF = 0n
          then repayAmountF := userAccount.borrow;
          else skip;

          userAccount.borrow :=
            case is_nat(userAccount.borrow - repayAmountF) of
              | None -> (failwith("yToken/cant-repay-more-than-borrowed") : nat)
              | Some(value) -> value
            end;

          if userAccount.borrow = 0n
          then borrowTokens := Set.remove(yAssetParams.tokenId, borrowTokens);
          else skip;

          s.accounts[(Tezos.sender, yAssetParams.tokenId)] := userAccount;
          token.totalBorrowsF :=
            case is_nat(token.totalBorrowsF - repayAmountF) of
              | None -> (failwith("underflow/totalBorrowsF") : nat)
              | Some(value) -> value
            end;
          token.totalLiquidF := token.totalLiquidF + repayAmountF;
          s.tokens[yAssetParams.tokenId] := token;
          s.borrows[Tezos.sender] := borrowTokens;
          const value : nat = ceil_div(repayAmountF, precision);
          operations := transfer_token(Tezos.sender, Tezos.self_address, value, token.mainToken);
        }
      | _                         -> skip
      end
  } with (operations, s)

function liquidate(
  const p               : useAction;
  var s                 : yStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Liquidate(params) -> {
          var userBorrowedTokens : set(tokenId) := getTokenIds(params.borrower, s.borrows);
          s.accounts := applyInterestToBorrows(userBorrowedTokens, params.borrower, s.accounts, s.tokens);
          var borrowerAccount : account := getAccount(params.borrower, params.borrowToken, s.accounts);
          var borrowToken : tokenType := getToken(params.borrowToken, s.tokens);

          ensureNotZero(params.amount);

          if params.borrowToken >= s.lastTokenId
          then failwith("yToken/borrow-id-undefined");
          else skip;

          if params.collateralToken >= s.lastTokenId
          then failwith("yToken/collateral-id-undefined");
          else skip;

          if Tezos.sender = params.borrower
          then failwith("yToken/borrower-cannot-be-liquidator")
          else skip;

          const liquidateCollateral : nat = calcLiquidateCollateral(
            getTokenIds(params.borrower, s.markets),
            params.borrower,
            s.ledger,
            s.tokens
          );
          const outstandingBorrowInCU : nat = calcOutstandingBorrowInCU(
            getTokenIds(params.borrower, s.borrows),
            params.borrower,
            s.accounts,
            s.ledger,
            s.tokens
          );

          if outstandingBorrowInCU <= liquidateCollateral
          then failwith("yToken/liquidation-not-achieved");
          else skip;
          if borrowerAccount.borrow = 0n
          then failwith("yToken/debt-is-zero");
          else skip;

          var liqAmountF : nat := params.amount * precision;
          (* liquidate amount can't be more than allowed close factor *)
          const maxClose : nat = borrowerAccount.borrow * s.closeFactorF / precision;

          if liqAmountF > maxClose
          then failwith("yToken/too-much-repay");
          else skip;

          borrowerAccount.borrow :=
            case is_nat(borrowerAccount.borrow - liqAmountF) of
              | None -> (failwith("underflow/borrowerAccount.borrow") : nat)
              | Some(value) -> value
            end;

          if borrowerAccount.borrow = 0n
          then userBorrowedTokens := Set.remove(params.borrowToken, userBorrowedTokens);
          else skip;

          borrowToken.totalBorrowsF :=
            case is_nat(borrowToken.totalBorrowsF - liqAmountF) of
              | None -> (failwith("underflow/totalBorrowsF") : nat)
              | Some(value) -> value
            end;
          borrowToken.totalLiquidF := borrowToken.totalLiquidF + liqAmountF;
          operations := transfer_token(Tezos.sender, Tezos.self_address, params.amount, borrowToken.mainToken);

          if getTokenIds(params.borrower, s.markets) contains params.collateralToken
          then skip
          else failwith("yToken/no-such-collateral");

          var collateralToken : tokenType := getToken(params.collateralToken, s.tokens);

          (* seizeAmount = actualRepayAmount * liquidationIncentive
            * priceBorrowed / priceCollateral
            seizeTokens = seizeAmount / exchangeRate
          *)
          const seizeAmount : nat = liqAmountF * s.liqIncentiveF
            * borrowToken.lastPrice * collateralToken.totalSupplyF;
          const liquidityF : nat = getLiquidity(collateralToken);
          const exchangeRateF : nat = liquidityF * precision * collateralToken.lastPrice;
          const seizeTokensF : nat = seizeAmount / exchangeRateF;
          var liquidatorAccount : account := getAccount(
            Tezos.sender,
            params.collateralToken,
            s.accounts
          );
          var borrowerBalance : nat := getBalanceByToken(params.borrower, params.collateralToken, s.ledger);
          var liquidatorBalance : nat := getBalanceByToken(Tezos.sender, params.collateralToken, s.ledger);

          borrowerBalance :=
            case is_nat(borrowerBalance - seizeTokensF) of
              | None -> (failwith("yToken/seize/not-enough-tokens") : nat)
              | Some(value) -> value
            end;
          liquidatorBalance := liquidatorBalance + seizeTokensF;

          s.ledger[(params.borrower, params.collateralToken)] := borrowerBalance;
          s.ledger[(Tezos.sender, params.collateralToken)] := liquidatorBalance;
          s.accounts[(params.borrower, params.borrowToken)] := borrowerAccount;
          s.accounts[(Tezos.sender, params.collateralToken)] := liquidatorAccount;
          s.tokens[params.collateralToken] := collateralToken;
          s.tokens[params.borrowToken] := borrowToken;
          s.borrows[params.borrower] := userBorrowedTokens;
        }
      | _                         -> skip
      end
  } with (operations, s)

function enterMarket(
  const p               : useAction;
  var s                 : yStorage)
                        : return is
  block {
    case p of
      EnterMarket(tokenId) -> {
        var userMarkets : set(tokenId) := getTokenIds(Tezos.sender, s.markets);

        if tokenId >= s.lastTokenId
        then failwith("yToken/yToken-undefined");
        else skip;

        if Set.size(userMarkets) >= s.maxMarkets
        then failwith("yToken/max-market-limit");
        else skip;

        userMarkets := Set.add(tokenId, userMarkets);
        s.markets[Tezos.sender] := userMarkets;
      }
    | _                         -> skip
    end
  } with (noOperations, s)

function exitMarket(
  const p               : useAction;
  var s                 : yStorage)
                        : return is
  block {
      case p of
        ExitMarket(tokenId) -> {
          var userMarkets : set(tokenId) := getTokenIds(Tezos.sender, s.markets);
          var userTokens : set(tokenId) := getTokenIds(Tezos.sender, s.borrows);
          s.accounts := applyInterestToBorrows(userTokens, Tezos.sender, s.accounts, s.tokens);
          userMarkets := Set.remove(tokenId, userMarkets);
          const maxBorrowInCU : nat = calcMaxCollateralInCU(
            userMarkets,
            Tezos.sender,
            s.ledger,
            s.tokens
          );
          const outstandingBorrowInCU : nat = calcOutstandingBorrowInCU(
            getTokenIds(Tezos.sender, s.borrows),
            Tezos.sender,
            s.accounts,
            s.ledger,
            s.tokens
          );

          if tokenId >= s.lastTokenId
          then failwith("yToken/yToken-undefined");
          else skip;

          if outstandingBorrowInCU <= maxBorrowInCU
          then s.markets[Tezos.sender] := userMarkets;
          else failwith("yToken/debt-not-repaid");
        }
      | _                         -> skip
      end
  } with (noOperations, s)

function priceCallback(
  const params          : yAssetParams;
  var s                 : fullStorage)
                        : fullReturn is
  block {
    if Tezos.sender =/= s.storage.priceFeedProxy
    then failwith("yToken/sender-is-not-price-feed");
    else skip;

    var token : tokenType := getToken(
      params.tokenId,
      s.storage.tokens
    );
    token.lastPrice := params.amount;
    token.priceUpdateTime := Tezos.now;
    s.storage.tokens[params.tokenId] := token;
  } with (noOperations, s)

function accrueInterest(
  const params          : yAssetParams;
  var s                 : fullStorage)
                        : fullReturn is
  block {
    var token : tokenType := getToken(params.tokenId, s.storage.tokens);
    const borrowRateF : nat = params.amount;

    if token.isInterestUpdating = False
    then failwith("yToken/interest-update-wrong-state");
    else token.isInterestUpdating := False;

    if Tezos.sender =/= token.interestRateModel
    then failwith("yToken/not-interest-rate-model-address")
    else skip;

    if borrowRateF >= token.maxBorrowRate
    then failwith("yToken/borrow-rate-is-absurdly-high");
    else skip;

    //  Calculate the number of blocks elapsed since the last accrual
    const blockDelta : nat =
      case is_nat(Tezos.now - token.interestUpdateTime) of
        | None -> (failwith("underflow/Tezos.now") : nat)
        | Some(value) -> value
      end;
    const simpleInterestFactorF : nat = borrowRateF * blockDelta;
    const interestAccumulatedF : nat = simpleInterestFactorF *
      token.totalBorrowsF / precision;

    token.totalBorrowsF := interestAccumulatedF + token.totalBorrowsF;
    // one mult operation with F require precision division
    token.totalReservesF := interestAccumulatedF * token.reserveFactorF /
      precision + token.totalReservesF;
    // one mult operation with F require precision division
    token.borrowIndex := simpleInterestFactorF * token.borrowIndex / precision + token.borrowIndex;
    token.interestUpdateTime := Tezos.now;

    s.storage.tokens[params.tokenId] := token;
  } with (noOperations, s)
