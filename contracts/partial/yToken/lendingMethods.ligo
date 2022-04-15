#include "./fa2Methods.ligo"
#include "./wrapTransfer.ligo"
#include "./adminMethods.ligo"

function getLiquidity(
  const token           : tokenType)
                        : nat is
  get_nat_or_fail(token.totalLiquidF + token.totalBorrowsF - token.totalReservesF, Errors.Math.lowLiquidityReserve);

function ensureNotZero(
  const amt             : nat)
                        : unit is
  require(amt > 0n, Errors.YToken.zeroAmount);

[@inline] function getBorrowRateContract(
  const rateAddress     : address)
                        : contract(rateParams) is
  unwrap(
    (Tezos.get_entrypoint_opt("%getBorrowRate", rateAddress): option(contract(rateParams))),
    Errors.YToken.borrowRate404
  )

[@inline] function ceil_div(
  const numerator       : nat;
  const denominator     : nat)
                        : nat is
  case ediv(numerator, denominator) of
    Some(result) -> if result.1 > 0n
      then result.0 + 1n
      else result.0
  | None -> failwith(Errors.Math.ceilDivision)
  end;

[@inline]
function verifyInterestUpdated(
    const token         : tokenType)
                        : unit is
    require(token.interestUpdateTime >= Tezos.now, Errors.YToken.needUpdate)

[@inline]
function verifyPriceUpdated(
    const token         : tokenType)
                        : unit is
    require(token.priceUpdateTime >= Tezos.now, Errors.YToken.needUpdate)


function calcMaxCollateralInCU(
  const userMarkets     : set(tokenId);
  const user            : address;
  const ledger          : big_map((address * tokenId), nat);
  const tokens          : big_map(tokenId, tokenType))
                        : nat is
  block {
    function oneToken(
      var acc           : nat;
      const tokenId     : tokenId)
                        : nat is
      block {
        const userBalance : nat = getBalanceByToken(user, tokenId, ledger);
        const token : tokenType = getToken(tokenId, tokens);
        if token.totalSupplyF > 0n then {
          const liquidityF : nat = getLiquidity(token);

          verifyPriceUpdated(token);
          verifyInterestUpdated(token);

          (* sum += collateralFactorF * exchangeRate * oraclePrice * balance *)
            acc := acc + userBalance * token.lastPrice
              * token.collateralFactorF * liquidityF / token.totalSupplyF / precision;
        }
        else skip;

      } with acc;
  } with Set.fold(oneToken, userMarkets, 0n)

function calcLiquidateCollateral(
  const userMarkets     : set(tokenId);
  const user            : address;
  const ledger          : big_map((address * tokenId), nat);
  const tokens          : big_map(tokenId, tokenType))
                        : nat is
  block {
    function oneToken(
      var acc           : nat;
      const tokenId     : tokenId)
                        : nat is
      block {
        const userBalance : nat = getBalanceByToken(user, tokenId, ledger);
        const token : tokenType = getToken(tokenId, tokens);
        if token.totalSupplyF > 0n then {
          const liquidityF : nat = getLiquidity(token);

          verifyPriceUpdated(token);
          verifyInterestUpdated(token);

          (* sum +=  balance * oraclePrice * exchangeRate *)
          acc := acc + userBalance * token.lastPrice * liquidityF / token.totalSupplyF;
        }
        else skip;
      } with acc * token.threshold / precision;
  } with Set.fold(oneToken, userMarkets, 0n)

function applyInterestToBorrows(
  const borrowedTokens  : set(tokenId);
  const user            : address;
  const accountsMap     : accountsMapType;
  const tokensMap       : big_map(tokenId, tokenType))
                        : accountsMapType is
  block {
    function oneToken(
      var userAccMap    : accountsMapType;
      const tokenId     : tokenId)
                        : accountsMapType is
      block {
        var userAccount : account := getAccount(user, tokenId, accountsMap);
        const token : tokenType = getToken(tokenId, tokensMap);

        verifyInterestUpdated(token);

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
  const tokens          : big_map(tokenId, tokenType))
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

        verifyPriceUpdated(token);

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
      require(tokenId < s.storage.lastTokenId, Errors.YToken.undefined);
      var _token : tokenType := getToken(tokenId, s.storage.tokens);
      var operations : list(operation) := list[];

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
        Mint(params) -> {
          ensureNotZero(params.amount);
          require(params.tokenId < s.lastTokenId, Errors.YToken.undefined);

          var mintTokensF : nat := params.amount * precision;
          var token : tokenType := getToken(params.tokenId, s.tokens);

          if token.totalSupplyF =/= 0n
          then {
            verifyInterestUpdated(token);
            const liquidityF : nat = getLiquidity(token);
            mintTokensF := mintTokensF * token.totalSupplyF / liquidityF;
          } else skip;

          require(mintTokensF / precision >= params.minReceived, Errors.YToken.highReceived);

          var userBalance : nat := getBalanceByToken(Tezos.sender, params.tokenId, s.ledger);
          userBalance := userBalance + mintTokensF;
          s.ledger[(Tezos.sender, params.tokenId)] := userBalance;
          token.totalSupplyF := token.totalSupplyF + mintTokensF;
          token.totalLiquidF := token.totalLiquidF + params.amount * precision;
          s.tokens[params.tokenId] := token;
          operations := transfer_token(Tezos.sender, Tezos.self_address, params.amount, token.mainToken);
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
        Redeem(params) -> {
          require(params.tokenId < s.lastTokenId, Errors.YToken.undefined);

          var token : tokenType := getToken(params.tokenId, s.tokens);
          var userBalance : nat := getBalanceByToken(Tezos.sender, params.tokenId, s.ledger);
          const liquidityF : nat = getLiquidity(token);
          const redeemAmount : nat = if params.amount = 0n
          then userBalance * liquidityF / token.totalSupplyF / precision
          else params.amount;
          require(redeemAmount >= params.minReceived, Errors.YToken.highReceived);
          var burnTokensF : nat := redeemAmount * precision * token.totalSupplyF / liquidityF;

          userBalance := get_nat_or_fail(userBalance - burnTokensF, Errors.YToken.lowBalance);
          s.ledger[(Tezos.sender, params.tokenId)] := userBalance;
          
          token.totalSupplyF := get_nat_or_fail(token.totalSupplyF - burnTokensF, Errors.YToken.lowSupply);
          token.totalLiquidF := get_nat_or_fail(token.totalLiquidF - redeemAmount * precision, Errors.YToken.lowLiquidity);

          s.tokens[params.tokenId] := token;
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

          require(outstandingBorrowInCU <= maxBorrowInCU, Errors.YToken.redeemExceeds);

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
        Borrow(params) -> {
          check_deadline(params.deadline);
          
          ensureNotZero(params.amount);

          require(params.tokenId < s.lastTokenId, Errors.YToken.undefined);

          var token : tokenType := getToken(params.tokenId, s.tokens);
          require(token.borrowPause = False, Errors.YToken.borrowPaused);


          var borrowTokens : set(tokenId) := getTokenIds(Tezos.sender, s.borrows);
          require(Set.size(borrowTokens) < s.maxMarkets, Errors.YToken.maxMarketLimit);

          borrowTokens := Set.add(params.tokenId, borrowTokens);
          s.accounts := applyInterestToBorrows(borrowTokens, Tezos.sender, s.accounts, s.tokens);
          var userAccount : account := getAccount(Tezos.sender, params.tokenId, s.accounts);
          const borrowsF : nat = params.amount * precision;

          userAccount.borrow := userAccount.borrow + borrowsF;
          s.accounts[(Tezos.sender, params.tokenId)] := userAccount;
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

          require(outstandingBorrowInCU <= maxBorrowInCU, Errors.YToken.debtExceeds);

          token.totalBorrowsF := token.totalBorrowsF + borrowsF;
          token.totalLiquidF := get_nat_or_fail(token.totalLiquidF - borrowsF, Errors.YToken.lowLiquidity);
          s.tokens[params.tokenId] := token;
          operations := transfer_token(Tezos.self_address, Tezos.sender, params.amount, token.mainToken);
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
        Repay(params) -> {
          check_deadline(params.deadline);

          require(params.tokenId < s.lastTokenId, Errors.YToken.undefined);

          var token : tokenType := getToken(params.tokenId, s.tokens);
          var borrowTokens : set(tokenId) := getTokenIds(Tezos.sender, s.borrows);
          s.accounts := applyInterestToBorrows(borrowTokens, Tezos.sender, s.accounts, s.tokens);
          var userAccount : account := getAccount(Tezos.sender, params.tokenId, s.accounts);
          var repayAmountF : nat := params.amount * precision;

          if repayAmountF = 0n
          then repayAmountF := userAccount.borrow;
          else skip;

          userAccount.borrow := get_nat_or_fail(userAccount.borrow - repayAmountF, Errors.YToken.repayOverflow);

          if userAccount.borrow = 0n
          then borrowTokens := Set.remove(params.tokenId, borrowTokens);
          else skip;

          s.accounts[(Tezos.sender, params.tokenId)] := userAccount;
          token.totalBorrowsF := get_nat_or_fail(token.totalBorrowsF - repayAmountF, Errors.YToken.lowTotalBorrow);
          token.totalLiquidF := token.totalLiquidF + repayAmountF;
          s.tokens[params.tokenId] := token;
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
          check_deadline(params.deadline);
          ensureNotZero(params.amount);
          require(
            params.collateralToken < s.lastTokenId and params.borrowToken < s.lastTokenId,
            Errors.YToken.marketId404
          );

          var userBorrowedTokens : set(tokenId) := getTokenIds(params.borrower, s.borrows);
          var userCollateralTokens : set(tokenId) := getTokenIds(params.borrower, s.markets);
          s.accounts := applyInterestToBorrows(userBorrowedTokens, params.borrower, s.accounts, s.tokens);
          var borrowerAccount : account := getAccount(params.borrower, params.borrowToken, s.accounts);
          var borrowToken : tokenType := getToken(params.borrowToken, s.tokens);

          require(Tezos.sender =/= params.borrower, Errors.YToken.borrowerNotLiquidator);

          const liquidateCollateral : nat = calcLiquidateCollateral(
            userCollateralTokens,
            params.borrower,
            s.ledger,
            s.tokens
          );
          const outstandingBorrowInCU : nat = calcOutstandingBorrowInCU(
            userBorrowedTokens,
            params.borrower,
            s.accounts,
            s.ledger,
            s.tokens
          );

          require(liquidateCollateral < outstandingBorrowInCU, Errors.YToken.cantLiquidate);

          var liqAmountF : nat := params.amount * precision;
          (* liquidate amount can't be more than allowed close factor *)
          const maxClose : nat = borrowerAccount.borrow * s.closeFactorF / precision;

          require(maxClose >= liqAmountF, Errors.YToken.repayOverflow);

          borrowerAccount.borrow := get_nat_or_fail(borrowerAccount.borrow - liqAmountF, Errors.YToken.lowBorrowAmount);

          if borrowerAccount.borrow = 0n
          then userBorrowedTokens := Set.remove(params.borrowToken, userBorrowedTokens);
          else skip;

          borrowToken.totalBorrowsF := get_nat_or_fail(borrowToken.totalBorrowsF - liqAmountF, Errors.YToken.lowTotalBorrow);
          borrowToken.totalLiquidF := borrowToken.totalLiquidF + liqAmountF;
          operations := transfer_token(Tezos.sender, Tezos.self_address, params.amount, borrowToken.mainToken);

          require(userCollateralTokens contains params.collateralToken, Errors.YToken.noCollateral);

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
          require(seizeTokensF / precision >= params.minSeized, Errors.YToken.highSeize);
          var liquidatorAccount : account := getAccount(
            Tezos.sender,
            params.collateralToken,
            s.accounts
          );
          var borrowerBalance : nat := getBalanceByToken(params.borrower, params.collateralToken, s.ledger);
          var liquidatorBalance : nat := getBalanceByToken(Tezos.sender, params.collateralToken, s.ledger);
          borrowerBalance := get_nat_or_fail(borrowerBalance - seizeTokensF, Errors.YToken.lowBorrowerBalanceS);
          liquidatorBalance := liquidatorBalance + seizeTokensF;
          
          (* collect reserves incentive from liquidation *)
          const reserveAmountF : nat = liqAmountF * collateralToken.liquidReserveRateF
            * borrowToken.lastPrice  * collateralToken.totalSupplyF;
          const reserveSharesF : nat = reserveAmountF / exchangeRateF;
          const reserveTokensF : nat = reserveSharesF * liquidityF / collateralToken.totalSupplyF;
          borrowerBalance := get_nat_or_fail(borrowerBalance - reserveSharesF, Errors.YToken.lowBorrowerBalanceR);
          collateralToken.totalReservesF := collateralToken.totalReservesF + reserveTokensF;
          collateralToken.totalSupplyF := get_nat_or_fail(collateralToken.totalSupplyF - reserveSharesF, Errors.YToken.lowCollateralTotalSupply);

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
        require(tokenId < s.lastTokenId, Errors.YToken.undefined);

        var userMarkets : set(tokenId) := getTokenIds(Tezos.sender, s.markets);

        require(Set.size(userMarkets) < s.maxMarkets, Errors.YToken.maxMarketLimit);

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
          require(tokenId < s.lastTokenId, Errors.YToken.undefined);

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

          require(outstandingBorrowInCU <= maxBorrowInCU, Errors.YToken.unpaidDebt);
          s.markets[Tezos.sender] := userMarkets;
        }
      | _                         -> skip
      end
  } with (noOperations, s)

function priceCallback(
  const params          : yAssetParams;
  var s                 : fullStorage)
                        : fullReturn is
  block {
    require(Tezos.sender = s.storage.priceFeedProxy, Errors.YToken.notProxy);

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

    require(token.isInterestUpdating, Errors.YToken.wrongUpdateState);
    token.isInterestUpdating := False;

    require(Tezos.sender = token.interestRateModel, Errors.YToken.notIR);
    require(borrowRateF < token.maxBorrowRate, Errors.YToken.highBorrowRate);

    //  Calculate the number of blocks elapsed since the last accrual
    const blockDelta : nat = get_nat_or_fail(Tezos.now - token.interestUpdateTime, Errors.YToken.timeOverflow);

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
