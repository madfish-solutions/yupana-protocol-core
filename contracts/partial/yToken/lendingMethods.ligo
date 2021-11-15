#include "./fa2Methods.ligo"
#include "./wrapTransfer.ligo"
#include "./adminMethods.ligo"

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
    const token         : tokenInfo)
                        : unit is
    if token.interestUpdateTime < Tezos.now or token.priceUpdateTime < Tezos.now
    then failwith("yToken/need-update")
    else unit;

function calcMaxCollateralInCU(
  const userMarkets     : set(tokenId);
  const user            : address;
  const ledger          : big_map((address * tokenId), nat);
  const tokenInfo       : map(tokenId, tokenInfo))
                        : nat is
  block {
    function oneToken(
      var acc           : nat;
      const tokenId     : tokenId)
                        : nat is
      block {
        const userBalance : nat = getBalanceByToken(user, tokenId, ledger);
        const token : tokenInfo = getTokenInfo(tokenId, tokenInfo);
        const numerator : nat =
          case is_nat(token.totalLiquidF + token.totalBorrowsF - token.totalReservesF) of
            | None -> (failwith("underflow/totalLiquidF+totalBorrowsF") : nat)
            | Some(value) -> value
          end;

        (* sum += collateralFactorF * exchangeRate * oraclePrice * balance *)
        acc := acc + ((userBalance * token.lastPrice
          * token.collateralFactorF) * (numerator / token.totalSupplyF) / precision);
      } with acc;
    const result : nat = Set.fold(
      oneToken,
      userMarkets,
      0n
    );
  } with result

function calCollateralValueInCU(
  const userMarkets     : set(tokenId);
  const user            : address;
  const ledger          : big_map((address * tokenId), nat);
  const tokenInfo       : map(tokenId, tokenInfo);
  const threshold       : nat)
                        : nat is
  block {
    function oneToken(
      var acc           : nat;
      const tokenId     : tokenId)
                        : nat is
      block {
        const userBalance : nat = getBalanceByToken(user, tokenId, ledger);
        const token : tokenInfo = getTokenInfo(tokenId, tokenInfo);
        const numerator : nat =
          case is_nat(token.totalLiquidF + token.totalBorrowsF - token.totalReservesF) of
            | None -> (failwith("underflow/totalLiquidF+totalBorrowsF") : nat)
            | Some(value) -> value
          end;

        (* sum += collateralFactorF * exchangeRate * oraclePrice * balance *)
        acc := acc + ((userBalance * token.lastPrice) * (numerator / token.totalSupplyF));
      } with acc;
    const collateralValue : nat = Set.fold(
      oneToken,
      userMarkets,
      0n
    );
    const result : nat = collateralValue * threshold / precision;
  } with result

function applyInterestToBorrows(
  const borrowedTokens      : set(tokenId);
  const user                : address;
  const accountsMap         : accountsMapType;
  const tokensMap           : map(tokenId, tokenInfo))
                            : accountsMapType is
  block {
    function oneToken(
      var userAccountsMap : accountsMapType;
      const tokenId       : tokenId)
                          : accountsMapType is
      block {
        var userAccount : account := getAccount(user, tokenId, accountsMap);
        const tokenInfo : tokenInfo = getTokenInfo(tokenId, tokensMap);

        verifyTokenUpdated(tokenInfo);

        if userAccount.lastBorrowIndex =/= 0n
          then userAccount.borrow := userAccount.borrow *
            tokenInfo.borrowIndex /
            userAccount.lastBorrowIndex;
          else skip;
      } with Map.update((user, tokenId), Some(userAccount), userAccountsMap);

    const result  = Set.fold(
      oneToken,
      borrowedTokens,
      accountsMap
    );
  } with (result)

function calcOutstandingBorrowInCU(
  const userBorrow      : set(tokenId);
  const user            : address;
  const accountInfo     : big_map((address * tokenId), account);
  const ledger          : big_map((address * tokenId), nat);
  const tokenInfo       : map(tokenId, tokenInfo))
                        : nat is
  block {
    function oneToken(
      var acc           : nat;
      var tokenId       : tokenId)
                        : nat is
      block {
        const userAccount : account = getAccount(user, tokenId, accountInfo);
        const userBalance : nat = getBalanceByToken(user, tokenId, ledger);
        var tokenInfo : tokenInfo := getTokenInfo(tokenId, tokenInfo);

        (* sum += oraclePrice * borrow *)
        if userBalance > 0n or userAccount.borrow > 0n
        then acc := acc + ((userAccount.borrow * tokenInfo.lastPrice));
        else skip;
      } with acc;
    const result : nat = Set.fold(
      oneToken,
      userBorrow,
      0n
    );
  } with result

function updateInterest(
  const tokenId         : nat;
  var s                 : fullTokenStorage)
                        : fullReturn is
    block {
      var _token : tokenInfo := getTokenInfo(tokenId, s.storage.tokenInfo);
      var operations : list(operation) := list[];

      if tokenId >= s.storage.lastTokenId
      then failwith("yToken/yToken-undefined");
      else skip;

      if _token.totalBorrowsF = 0n
      then block {
        _token.interestUpdateTime := Tezos.now;
        s.storage.tokenInfo[tokenId] := _token;
      }
      else block {
        _token.isInterestUpdating := True;
        operations := list[
        Tezos.transaction(
          record[
            tokenId = tokenId;
            borrowsF = _token.totalBorrowsF;
            cashF = _token.totalLiquidF;
            reservesF = _token.totalReservesF;
            reserveFactorF = _token.reserveFactorF;
            precision = precision;
            callback = (Tezos.self("%accrueInterest") : contract(yAssetParams));
          ],
          0mutez,
          getBorrowRateContract(_token.interestRateModel)
        )];
        s.storage.tokenInfo[tokenId] := _token;
      }
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

          if yAssetParams.tokenId >= s.lastTokenId
          then failwith("yToken/yToken-undefined");
          else skip;

          var mintTokensF : nat := yAssetParams.amount * precision;
          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s.tokenInfo);

          if token.totalSupplyF =/= 0n
          then {
            verifyTokenUpdated(token);

            const numerator : nat =
              case is_nat(token.totalLiquidF + token.totalBorrowsF - token.totalReservesF) of
                | None -> (failwith("underflow/totalLiquidF+totalBorrowsF") : nat)
                | Some(value) -> value
              end;

            mintTokensF := mintTokensF * token.totalSupplyF / numerator;
          } else skip;

          var userBalance : nat := getBalanceByToken(Tezos.sender, yAssetParams.tokenId, s.ledger);
          userBalance := userBalance + mintTokensF;

          s.ledger[(Tezos.sender, yAssetParams.tokenId)] := userBalance;

          token.totalSupplyF := token.totalSupplyF + mintTokensF;
          token.totalLiquidF := token.totalLiquidF + mintTokensF;
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
          if yAssetParams.tokenId >= s.lastTokenId
          then failwith("yToken/yToken-undefined");
          else skip;

          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s.tokenInfo);

          verifyTokenUpdated(token);

          if Set.mem(yAssetParams.tokenId, getTokenIds(Tezos.sender, s.markets))
          then failwith("yToken/token-taken-as-collateral")
          else skip;

          var userBalance : nat := getBalanceByToken(Tezos.sender, yAssetParams.tokenId, s.ledger);

          const liquidityF : nat =
            case is_nat(token.totalLiquidF + token.totalBorrowsF - token.totalReservesF) of
              | None -> (failwith("underflow/totalLiquidF+totalBorrowsF") : nat)
              | Some(value) -> value
            end;

          const redeemAmount : nat = if yAssetParams.amount = 0n
          then userBalance * liquidityF / token.totalSupplyF / precision
          else yAssetParams.amount;

          if redeemAmount * precision > token.totalLiquidF
          then failwith("yToken/not-enough-liquid")
          else skip;

          var burnTokensF : nat := redeemAmount * precision *
            token.totalSupplyF / liquidityF;
          if userBalance < burnTokensF
          then failwith("yToken/not-enough-tokens-to-burn")
          else skip;

          userBalance :=
            case is_nat(userBalance - burnTokensF) of
              | None -> (failwith("underflow/userBalance") : nat)
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

          if yAssetParams.tokenId >= s.lastTokenId
          then failwith("yToken/yToken-undefined");
          else skip;

          var userAccount : account := getAccount(Tezos.sender, yAssetParams.tokenId, s.accountInfo);
          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s.tokenInfo);
          var borrowTokens : set(tokenId) := getTokenIds(Tezos.sender, s.borrows);

          verifyTokenUpdated(token);

          if token.borrowPause
          then failwith("yToken/forbidden-for-borrow");
          else skip;

          const borrowsF : nat = yAssetParams.amount * precision;

          if borrowsF > token.totalLiquidF
          then failwith("yToken/amount-too-big")
          else skip;

          s.accountInfo := applyInterestToBorrows(borrowTokens, Tezos.sender, s.accountInfo, s.tokenInfo);
          borrowTokens := Set.add(yAssetParams.tokenId, borrowTokens);

          userAccount.lastBorrowIndex := token.borrowIndex;
          userAccount.borrow := userAccount.borrow + borrowsF;
          s.accountInfo[(Tezos.sender, yAssetParams.tokenId)] := userAccount;
          s.borrows[Tezos.sender] := borrowTokens;

          const maxBorrowInCU : nat = calcMaxCollateralInCU(
            getTokenIds(Tezos.sender, s.markets),
            Tezos.sender,
            s.ledger,
            s.tokenInfo
          );

          const outstandingBorrowInCU : nat = calcOutstandingBorrowInCU(
            getTokenIds(Tezos.sender, s.borrows),
            Tezos.sender,
            s.accountInfo,
            s.ledger,
            s.tokenInfo
          );

          if outstandingBorrowInCU > maxBorrowInCU
          then failwith("yToken/exceeds-the-permissible-debt");
          else skip;

          token.totalBorrowsF := token.totalBorrowsF + borrowsF;
          token.totalLiquidF :=
            case is_nat(token.totalLiquidF - borrowsF) of
              | None -> (failwith("underflow/totalLiquidF") : nat)
              | Some(value) -> value
            end;

          s.tokenInfo[yAssetParams.tokenId] := token;

          operations := transfer_token(Tezos.self_address, Tezos.sender, yAssetParams.amount, token.mainToken);
        }
      | _                         -> skip
      end
  } with (operations, s)

function repay(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Repay(yAssetParams) -> {
          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s.tokenInfo);

          if yAssetParams.tokenId >= s.lastTokenId
          then failwith("yToken/yToken-undefined");
          else skip;

          verifyTokenUpdated(token);

          var repayAmountF : nat := yAssetParams.amount * precision;

          var userAccount : account := getAccount(Tezos.sender, yAssetParams.tokenId, s.accountInfo);
          var borrowTokens : set(tokenId) := getTokenIds(Tezos.sender, s.borrows);

          if userAccount.lastBorrowIndex =/= 0n
          then userAccount.borrow := userAccount.borrow *
            token.borrowIndex / userAccount.lastBorrowIndex;
          else skip;

          if repayAmountF = 0n
          then repayAmountF := userAccount.borrow;
          else skip;

          if repayAmountF > userAccount.borrow
          then failwith("yToken/amount-should-be-less-or-equal")
          else skip;

          userAccount.borrow :=
            case is_nat(userAccount.borrow - repayAmountF) of
              | None -> (failwith("underflow/userAccount.borrow") : nat)
              | Some(value) -> value
            end;

          if userAccount.borrow = 0n
          then borrowTokens := Set.remove(yAssetParams.tokenId, borrowTokens);
          else skip;

          userAccount.lastBorrowIndex := token.borrowIndex;
          s.accountInfo[(Tezos.sender, yAssetParams.tokenId)] := userAccount;
          token.totalBorrowsF :=
            case is_nat(token.totalBorrowsF - repayAmountF) of
              | None -> (failwith("underflow/totalBorrowsF") : nat)
              | Some(value) -> value
            end;

          token.totalLiquidF := token.totalLiquidF + repayAmountF;
          s.tokenInfo[yAssetParams.tokenId] := token;
          s.borrows[Tezos.sender] := borrowTokens;

          const value : nat = ceil_div(repayAmountF, precision);
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

          if params.borrowToken >= s.lastTokenId
          then failwith("yToken/yToken-undefined(borrowToken)");
          else skip;

          if params.collateralToken >= s.lastTokenId
          then failwith("yToken/yToken-undefined(collateralToken)");
          else skip;

          var userBorrowedTokens : set(tokenId) := getTokenIds(params.borrower, s.borrows);
          s.accountInfo := applyInterestToBorrows(userBorrowedTokens, params.borrower, s.accountInfo, s.tokenInfo);
          var borrowerAccount : account := getAccount(params.borrower, params.borrowToken, s.accountInfo);
          var borrowToken : tokenInfo := getTokenInfo(params.borrowToken, s.tokenInfo);

          verifyTokenUpdated(borrowToken);

          if Tezos.sender = params.borrower
          then failwith("yToken/borrower-cannot-be-liquidator")
          else skip;

          const maxBorrowInCU : nat = calCollateralValueInCU(
            getTokenIds(params.borrower, s.markets),
            params.borrower,
            s.ledger,
            s.tokenInfo,
            s.threshold
          );

          const outstandingBorrowInCU : nat = calcOutstandingBorrowInCU(
            getTokenIds(params.borrower, s.borrows),
            params.borrower,
            s.accountInfo,
            s.ledger,
            s.tokenInfo
          );

          if outstandingBorrowInCU <= maxBorrowInCU
          then failwith("yToken/liquidation-not-achieved");
          else skip;
          if borrowerAccount.borrow = 0n
          then failwith("yToken/debt-is-zero");
          else skip;

          var liqAmountF : nat := params.amount * precision;


          (* liquidate amount can't be more than allowed close factor *)
          const maxClose : nat = borrowerAccount.borrow * s.closeFactorF
            / precision;

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

          borrowerAccount.lastBorrowIndex := borrowToken.borrowIndex;
          borrowToken.totalBorrowsF :=
            case is_nat(borrowToken.totalBorrowsF - liqAmountF) of
              | None -> (failwith("underflow/totalBorrowsF") : nat)
              | Some(value) -> value
            end;

          borrowToken.totalLiquidF := borrowToken.totalLiquidF + liqAmountF;

          operations := transfer_token(Tezos.sender, Tezos.self_address, params.amount, borrowToken.mainToken);

          if getTokenIds(params.borrower, s.markets) contains params.collateralToken
          then skip
          else failwith("yToken/collateralToken-not-contains-in-borrow-market");

          var collateralToken : tokenInfo := getTokenInfo(params.collateralToken, s.tokenInfo);

          verifyTokenUpdated(collateralToken);

          (* seizeAmount = actualRepayAmount * liquidationIncentive
            * priceBorrowed / priceCollateral
            seizeTokens = seizeAmount / exchangeRate
          *)
          const seizeAmount : nat = liqAmountF * s.liqIncentiveF
            * borrowToken.lastPrice * collateralToken.totalSupplyF;

          const numerator : nat =
            case is_nat(collateralToken.totalLiquidF + collateralToken.totalBorrowsF
            - collateralToken.totalReservesF) of
              | None -> (failwith("underflow/totalLiquidF+totalBorrowsF") : nat)
              | Some(value) -> value
            end;

          const exchangeRateF : nat = numerator * precision * collateralToken.lastPrice;

          const seizeTokensF : nat = seizeAmount / exchangeRateF;

          var liquidatorAccount : account := getAccount(
            Tezos.sender,
            params.collateralToken,
            s.accountInfo
          );

          var borrowerBalance : nat := getBalanceByToken(params.borrower, params.collateralToken, s.ledger);

          if borrowerBalance < seizeTokensF
          then failwith("yToken/seize/not-enough-tokens")
          else skip;

          var liquidatorBalance : nat := getBalanceByToken(Tezos.sender, params.collateralToken, s.ledger);

          borrowerBalance :=
            case is_nat(borrowerBalance - seizeTokensF) of
              | None -> (failwith("underflow/borrowerBalance") : nat)
              | Some(value) -> value
            end;

          liquidatorBalance := liquidatorBalance + seizeTokensF;

          s.ledger[(params.borrower, params.collateralToken)] := borrowerBalance;
          s.ledger[(Tezos.sender, params.collateralToken)] := liquidatorBalance;
          s.accountInfo[(params.borrower, params.borrowToken)] := borrowerAccount;
          s.accountInfo[(Tezos.sender, params.collateralToken)] := liquidatorAccount;
          s.tokenInfo[params.collateralToken] := collateralToken;
          s.borrows[params.borrower] := userBorrowedTokens;
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
        var userAccount : account := getAccount(Tezos.sender, tokenId, s.accountInfo);
        var userMarkets : set(tokenId) := getTokenIds(Tezos.sender, s.markets);

        if tokenId >= s.lastTokenId
        then failwith("yToken/yToken-undefined");
        else skip;

        if Set.size(userMarkets) >= s.maxMarkets
        then failwith("yToken/max-market-limit");
        else skip;

        userMarkets := Set.add(tokenId, userMarkets);
        s.markets[Tezos.sender] := userMarkets;
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
          var userMarkets : set(tokenId) := getTokenIds(Tezos.sender, s.markets);
          var userTokens : set(tokenId) := getTokenIds(Tezos.sender, s.borrows);

          if tokenId >= s.lastTokenId
          then failwith("yToken/yToken-undefined");
          else skip;

          const token : tokenInfo = getTokenInfo(
            tokenId,
            s.tokenInfo
          );
          verifyTokenUpdated(token);

          userMarkets := Set.remove(tokenId, userMarkets);

          s.accountInfo := applyInterestToBorrows(userTokens, Tezos.sender, s.accountInfo, s.tokenInfo);

          const maxBorrowInCU : nat = calcMaxCollateralInCU(
            userMarkets,
            Tezos.sender,
            s.ledger,
            s.tokenInfo
          );
          const outstandingBorrowInCU : nat = calcOutstandingBorrowInCU(
            getTokenIds(Tezos.sender, s.borrows),
            Tezos.sender,
            s.accountInfo,
            s.ledger,
            s.tokenInfo
          );

          if outstandingBorrowInCU <= maxBorrowInCU
          then s.markets[Tezos.sender] := userMarkets;
          else failwith("yToken/debt-not-repaid");
        }
      | _                         -> skip
      end
  } with (noOperations, s)

function priceCallback(
  const params          : yAssetParams;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    if Tezos.sender =/= s.storage.priceFeedProxy
    then failwith("yToken/permition-error");
    else skip;

    var token : tokenInfo := getTokenInfo(
      params.tokenId,
      s.storage.tokenInfo
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
    var token : tokenInfo := getTokenInfo(params.tokenId, s.storage.tokenInfo);
    const borrowRate : nat = params.amount;

    if token.isInterestUpdating = False
    then failwith("yToken/interest-update-wrong-state");
    else token.isInterestUpdating := False;

    if Tezos.sender =/= token.interestRateModel
    then failwith("yToken/not-interest-rate-model-address")
    else skip;

    if borrowRate >= token.maxBorrowRate
    then failwith("yToken/borrow-rate-is-absurdly-high");
    else skip;

    //  Calculate the number of blocks elapsed since the last accrual
    const blockDelta : nat =
      case is_nat(Tezos.now - token.interestUpdateTime) of
        | None -> (failwith("underflow/Tezos.now") : nat)
        | Some(value) -> value
      end;

    const simpleInterestFactorF : nat = borrowRate * blockDelta;
    const interestAccumulatedF : nat = simpleInterestFactorF *
      token.totalBorrowsF / precision;

    token.totalBorrowsF := interestAccumulatedF + token.totalBorrowsF;
    // one mult operation with F require precision division
    token.totalReservesF := interestAccumulatedF * token.reserveFactorF /
      precision + token.totalReservesF;
    // one mult operation with F require precision division
    token.borrowIndex := simpleInterestFactorF * token.borrowIndex / precision + token.borrowIndex;
    token.interestUpdateTime := Tezos.now;

    s.storage.tokenInfo[params.tokenId] := token;
  } with (noOperations, s)
