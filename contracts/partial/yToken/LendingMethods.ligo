#include "./FA2Methods.ligo"
#include "./AdminMethods.ligo"

function calculateMaxCollaterallInXtz(
  var userAccount       : account;
  var params            : prms)
                        : nat is
  block {
    function oneToken(
      var param         : prms;
      var tokenId       : nat)
                        : prms is
      block {
        var token : tokenInfo := getTokenInfo(tokenId, param.s);
        var _userBalance : nat := getMapInfo(
          param.userAccount.balances,
          tokenId
        );
        const balance_Oracle : nat = 10n; // TEST!!
        param.res := param.res + (balance_Oracle * token.reserveFactor);
      } with param;
    var result : prms := Set.fold(oneToken, userAccount.markets, params);
  } with result.res

function calculateOutstandingBorrowInXtz(
  var userAccount       : account;
  var params            : prms)
                        : nat is
  block {
    function oneToken(
      var param         : prms;
      var tokenId       : nat)
                        : prms is
      block {
        var _token : tokenInfo := getTokenInfo(tokenId, param.s);
        var borrowBalance : nat := getMapInfo(
          param.userAccount.borrowAmount,
          tokenId
        );
        const priceInXtz : nat = 10n; // TEST!!
        param.res := param.res + (borrowBalance * priceInXtz);
      } with param;
    var result : prms := Set.fold(oneToken, userAccount.markets, params);
  } with result.res

function updateInterest(
  var tokenId           : nat;
  var s                 : tokenStorage)
                        : tokenStorage is
  block {
    var token : tokenInfo := getTokenInfo(tokenId, s);
    if token.lastUpdateTime = Tezos.now
    then failwith("SimulatTime")
    else skip;

    const _cashPrior : nat = token.totalLiquid;
    const borrowsPrior : nat = token.totalBorrows;
    const _reservesPrior : nat = token.totalReserves;
    const _borrowIndexPrior : nat = token.borrowIndex;

    // ???
    var borrowRate : nat := 0n;
    // var borrowRate = token.interestRateModel.getBorrowRate(cashPrior, borrowsPrior, reservesPrior);
    // if borrowRate <= borrowRateMaxMantissa
    // then failwith("borrow rate is absurdly high");
    // else skip;
    // borrowRateMaxMantissa ???

    //  Calculate the number of blocks elapsed since the last accrual
    var blockDelta : nat := abs(Tezos.now - token.lastUpdateTime);

    const simpleInterestFactor : nat = borrowRate * blockDelta;
    const interestAccumulated : nat = simpleInterestFactor * borrowsPrior;

    token.totalBorrows := interestAccumulated + token.totalBorrows;
    // one mult operation with float require accuracy division
    token.totalReserves := interestAccumulated * token.reserveFactor /
      accuracy + token.totalReserves;
    // one mult operation with float require accuracy division
    token.borrowIndex := simpleInterestFactor * token.borrowIndex /
      accuracy + token.borrowIndex;
    token.lastUpdateTime := Tezos.now;

    s.tokenInfo[tokenId] := token;
  } with s

function mint(
  const p               : useAction;
  var s                 : tokenStorage;
  const this            : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Mint(mainParams) -> {
          var mintTokens : nat := mainParams.amount * accuracy;
          var token : tokenInfo := getTokenInfo(mainParams.tokenId, s);

          if token.totalSupply =/= 0n
          then block {
            s := updateInterest(mainParams.tokenId, s);
            mintTokens := mainParams.amount * token.totalSupply * accuracy / abs(
              token.totalLiquid + token.totalBorrows - token.totalReserves
            );
          }
          else skip;

          var userAccount : account := getAccount(Tezos.sender, s);
          var userBalance : nat := getMapInfo(
            userAccount.balances,
            mainParams.tokenId
          );

          userBalance := userBalance + mintTokens;

          userAccount.balances[mainParams.tokenId] := userBalance;
          s.accountInfo[Tezos.sender] := userAccount;
          token.totalSupply := token.totalSupply + mintTokens;
          token.totalLiquid := token.totalLiquid + mainParams.amount * accuracy;
          s.tokenInfo[mainParams.tokenId] := token;

          operations := list [
            Tezos.transaction(
              TransferOutside(record [
                from_ = Tezos.sender;
                to_ = this;
                value = mainParams.amount
              ]),
              0mutez,
              getTokenContract(token.mainToken)
            )
          ];
        }
      | _                         -> skip
      end
  } with (operations, s)

function redeem(
  const p               : useAction;
  var s                 : tokenStorage;
  const this            : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Redeem(mainParams) -> {
          s := updateInterest(mainParams.tokenId, s);

          var accountUser : account := getAccount(Tezos.sender, s);
          if Set.mem(mainParams.tokenId, accountUser.markets)
          then failwith("TokenTakenAsCollateral")
          else skip;

          var userBalance : nat := getMapInfo(
            accountUser.balances,
            mainParams.tokenId
          );
          var token : tokenInfo := getTokenInfo(mainParams.tokenId, s);

          const liquidity : nat = abs(
              token.totalLiquid + token.totalBorrows - token.totalReserves);
          const redeemAmount : nat = if mainParams.amount = 0n
          then userBalance * liquidity / token.totalSupply / accuracy
          else mainParams.amount;

          if token.totalLiquid < redeemAmount
          then failwith("NotEnoughLiquid")
          else skip;

          var burnTokens : nat := redeemAmount * accuracy *
            token.totalSupply / liquidity;
          if userBalance < burnTokens
          then failwith("NotEnoughTokensToBurn")
          else skip;

          userBalance := abs(userBalance - burnTokens);
          accountUser.balances[mainParams.tokenId] := userBalance;
          s.accountInfo[Tezos.sender] := accountUser;
          token.totalSupply := abs(token.totalSupply - burnTokens);
          token.totalLiquid := abs(token.totalLiquid - redeemAmount *
            accuracy);
          s.tokenInfo[mainParams.tokenId] := token;

          operations := list [
            Tezos.transaction(
              TransferOutside(record [
                from_ = this;
                to_ = Tezos.sender;
                value = redeemAmount
              ]),
              0mutez,
              getTokenContract(token.mainToken)
            )
          ]
        }
      | _                         -> skip
      end
  } with (operations, s)

function borrow(
  const p               : useAction;
  var s                 : tokenStorage;
  const this            : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Borrow(mainParams) -> {
          s := updateInterest(mainParams.tokenId, s);
          var token : tokenInfo := getTokenInfo(mainParams.tokenId, s);

          if token.totalLiquid < mainParams.amount
          then failwith("AmountTooBig")
          else skip;

          var accountUser : account := getAccount(Tezos.sender, s);

          var maxBorrowInXtz : nat := calculateMaxCollaterallInXtz(
            accountUser,
            record[s = s; res = 0n; userAccount = accountUser]
          );
          var outstandingBorrowInXtz : nat := calculateOutstandingBorrowInXtz(
            accountUser,
            record[s = s; res = 0n; userAccount = accountUser]
          );
          var availableToBorrowInXtz : nat := abs(
            maxBorrowInXtz - outstandingBorrowInXtz
          );
          // var maxBorrowXAmount : nat := availableToBorrowInXtz /
          //   getPrice(mainParams.tokenId);
          var maxBorrowXAmount : nat := availableToBorrowInXtz /
            10n;

          var userBorrowAmount : nat := getMapInfo(
            accountUser.borrowAmount,
            mainParams.tokenId
          );
          var lastBorrowIndex : nat := getMapInfo(
            accountUser.lastBorrowIndex,
            mainParams.tokenId
          );

          if lastBorrowIndex =/= 0n
          then userBorrowAmount := userBorrowAmount *
              token.borrowIndex / lastBorrowIndex;
          else skip;

          userBorrowAmount := userBorrowAmount + mainParams.amount;

          if maxBorrowXAmount > userBorrowAmount
          then failwith("MoreThenAvailableBorrow")
          else skip;

          lastBorrowIndex := token.borrowIndex;
          accountUser.borrowAmount[mainParams.tokenId] := userBorrowAmount;
          accountUser.lastBorrowIndex[mainParams.tokenId] := lastBorrowIndex;
          s.accountInfo[Tezos.sender] := accountUser;
          token.totalBorrows := token.totalBorrows + mainParams.amount;
          token.totalLiquid := abs(token.totalLiquid - mainParams.amount);
          s.tokenInfo[mainParams.tokenId] := token;

          operations := list [
            Tezos.transaction(
              TransferOutside(record [
                from_ = this;
                to_ = Tezos.sender;
                value = mainParams.amount
              ]),
              0mutez,
              getTokenContract(token.mainToken)
            )
          ]
        }
      | _                         -> skip
      end
  } with (operations, s)

function repay (
  const p               : useAction;
  var s                 : tokenStorage;
  const this            : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Repay(mainParams) -> {
          s := updateInterest(mainParams.tokenId, s);
          var repayAmount : nat := mainParams.amount;

          var accountUser : account := getAccount(Tezos.sender, s);
          var token : tokenInfo := getTokenInfo(mainParams.tokenId, s);
          var lastBorrowIndex : nat := getMapInfo(
            accountUser.lastBorrowIndex,
            mainParams.tokenId
          );
          var userBorrowAmount : nat := getMapInfo(
            accountUser.borrowAmount,
            mainParams.tokenId
          );

          if lastBorrowIndex =/= 0n
          then userBorrowAmount := userBorrowAmount *
            token.borrowIndex / lastBorrowIndex;
          else skip;

          if repayAmount = 0n
          then repayAmount := userBorrowAmount;
          else skip;

          if userBorrowAmount < repayAmount
          then failwith("AmountShouldBeLessOrEqual")
          else skip;

          userBorrowAmount := abs(
            userBorrowAmount - repayAmount
          );
          lastBorrowIndex := token.borrowIndex;

          accountUser.lastBorrowIndex[mainParams.tokenId] := lastBorrowIndex;
          accountUser.borrowAmount[mainParams.tokenId] := userBorrowAmount;
          s.accountInfo[Tezos.sender] := accountUser;
          token.totalBorrows := abs(token.totalBorrows - repayAmount);
          s.tokenInfo[mainParams.tokenId] := token;


          operations := list [
            Tezos.transaction(
              TransferOutside(record [
                from_ = Tezos.sender;
                to_ = this;
                value = repayAmount
              ]),
              0mutez,
              getTokenContract(token.mainToken)
            )
          ]
        }
      | _                         -> skip
      end
  } with (operations, s)

function liquidate(
  const p               : useAction;
  var s                 : tokenStorage;
  const this            : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Liquidate(liquidateParams) -> {
          s := updateInterest(liquidateParams.borrowToken, s);

          if Tezos.sender = liquidateParams.borrower
          then failwith("BorrowerCannotBeLiquidator")
          else skip;

          var accountBorrower : account := getAccount(
            liquidateParams.borrower,
            s
          );
          var borrowToken : tokenInfo := getTokenInfo(
            liquidateParams.borrowToken,
            s
          );
          var borrowerBorrowAmount : nat := getMapInfo(
            accountBorrower.borrowAmount,
            liquidateParams.borrowToken
          );
          var borrowerLastBorrowIndex : nat := getMapInfo(
            accountBorrower.lastBorrowIndex,
            liquidateParams.borrowToken
          );
          var maxBorrowInXtz : nat := calculateMaxCollaterallInXtz(
            accountBorrower,
            record[s = s; res = 0n; userAccount = accountBorrower]
          );
          var outstandingBorrowInXtz : nat := calculateOutstandingBorrowInXtz(
            accountBorrower,
            record[s = s; res = 0n; userAccount = accountBorrower]
          );

          if outstandingBorrowInXtz > maxBorrowInXtz
          then skip
          else failwith("LiquidatinoNotAchieved");

          if borrowerBorrowAmount = 0n
          then failwith("DebtIsZero");
          else skip;

          var liquidateAmount : nat := liquidateParams.amount;

          if borrowerLastBorrowIndex =/= 0n
          then borrowerBorrowAmount := borrowerBorrowAmount *
            borrowToken.borrowIndex /
            borrowerLastBorrowIndex;
          else skip;

          if borrowerBorrowAmount < liquidateAmount
          then failwith("AmountShouldBeLessOrEqual")
          else skip;

          borrowerBorrowAmount := abs(
            borrowerBorrowAmount - liquidateAmount
          );
          borrowerLastBorrowIndex := borrowToken.borrowIndex;
          borrowToken.totalBorrows := abs(
            borrowToken.totalBorrows - liquidateAmount
          );

          accountBorrower.lastBorrowIndex[
            liquidateParams.borrowToken
          ] := borrowerLastBorrowIndex;
          accountBorrower.borrowAmount[
            liquidateParams.borrowToken
          ] := borrowerBorrowAmount;
          s.accountInfo[liquidateParams.borrower] := accountBorrower;

          operations := list [
            Tezos.transaction(
              TransferOutside(record [
                from_ = Tezos.sender;
                to_ = this;
                value = liquidateAmount
              ]),
              0mutez,
              getTokenContract(borrowToken.mainToken)
            )
          ];

          var collateralToken : tokenInfo := getTokenInfo(
            liquidateParams.collateralToken,
            s
          );

          const exchangeRateFloat : nat = abs(
            collateralToken.totalLiquid + collateralToken.totalBorrows -
              collateralToken.totalReserves
          ) * accuracy / collateralToken.totalSupply;
          const seizeTokensFloat : nat = liquidateParams.amount * accuracy /
            exchangeRateFloat;

          var borrowerTokensFloat : account := getAccount(
            liquidateParams.borrower,
            s
          );
          var liquidatorAccount : account := getAccount(
            Tezos.sender,
            s
          );

          var borrowerBalance : nat := getMapInfo(
            borrowerTokensFloat.balances,
            liquidateParams.collateralToken
          );
          var liquidatorBalance : nat := getMapInfo(
            liquidatorAccount.balances,
            liquidateParams.collateralToken
          );

          if borrowerBalance < seizeTokensFloat
          then failwith("NotEnoughTokens seize")
          else skip;

          borrowerBalance := abs(borrowerBalance - seizeTokensFloat);
          liquidatorBalance := liquidatorBalance + seizeTokensFloat;

          borrowerTokensFloat.balances[
            liquidateParams.collateralToken
          ] := borrowerBalance;
          liquidatorAccount.balances[
            liquidateParams.collateralToken
          ] := liquidatorBalance;
          s.accountInfo[liquidateParams.borrower] := borrowerTokensFloat;
          s.accountInfo[Tezos.sender] := liquidatorAccount;
          s.tokenInfo[liquidateParams.collateralToken] := collateralToken;
        }
      | _                         -> skip
      end
  } with (operations, s)

function enterMarket(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        EnterMarket(tokenId) -> {
          var userAccount : account := getAccount(Tezos.sender,s);
          const cardinal : nat = Set.size(userAccount.markets);
          var userBalance : nat := getMapInfo(
            userAccount.balances,
            tokenId
          );

          if userBalance = 0n
          then failwith("NotEnoughTokensForEnter");
          else skip;

          if cardinal + 1n > maxMarkets
          then failwith("MaxMarketLimit");
          else skip;

          userAccount.markets := Set.add(tokenId, userAccount.markets);
          userAccount.balances[tokenId] := userBalance;
          s.accountInfo[Tezos.sender] := userAccount;
        }
      | _                         -> skip
      end
  } with (operations, s)

  function exitMarket(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        ExitMarket(tokenId) -> {
          var userAccount : account := getAccount(Tezos.sender,s);
          userAccount.markets := Set.remove(tokenId, userAccount.markets);

          var maxBorrowInXtz : nat := calculateMaxCollaterallInXtz(
            userAccount,
            record[s = s; res = 0n; userAccount = userAccount]
          );
          var outstandingBorrowInXtz : nat := calculateOutstandingBorrowInXtz(
            userAccount,
            record[s = s; res = 0n; userAccount = userAccount]
          );

          if outstandingBorrowInXtz < maxBorrowInXtz
          then s.accountInfo[Tezos.sender] := userAccount;
          else failwith("DebtNotRepaid");
        }
      | _                         -> skip
      end
  } with (operations, s)
