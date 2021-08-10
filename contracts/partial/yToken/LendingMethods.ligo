#include "./FA2Methods.ligo"
#include "./AdminMethods.ligo"

[@inline] function getEnsuredExitMarketEntrypoint(
  const selfAddress     : address)
                        : contract(useAction) is
  case (
    Tezos.get_entrypoint_opt("%ensuredExitMarket", selfAddress)
                        : option(contract(useAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("cant-get-exitMarket-entrypoint")
                        : contract(useAction)
    )
  end;

[@inline] function getEnsuredBorrowEntrypoint(
  const selfAddress     : address)
                        : contract(useAction) is
  case (
    Tezos.get_entrypoint_opt("%ensuredBorrow", selfAddress)
                        : option(contract(useAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("cant-get-borrow-entrypoint")
                        : contract(useAction)
    )
  end;

[@inline] function getEnsuredLiquidateEntrypoint(
  const selfAddress     : address)
                        : contract(useAction) is
  case (
    Tezos.get_entrypoint_opt("%ensuredLiquidate", selfAddress)
                        : option(contract(useAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("cant-get-ensuredLiquidate-entrypoint")
                        : contract(useAction)
    )
  end;

function getProxyContract(
  const priceFeedProxy  : address)
                        : contract(proxyAction) is
  case(
    Tezos.get_entrypoint_opt("%getPrice", priceFeedProxy)
                        : option(contract(proxyAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("cant-get-contract-proxy") : contract(proxyAction)
    )
  end;

function addToSet(
  const fullMap         : map(tokenId, nat))
                        : set(tokenId) is
    block {
      var res : set(tokenId) := Set.empty;
      function add(
        var res         : set(tokenId);
        const currPair  : tokenId * nat)
                        : set(tokenId) is
          Set.add(currPair.0, res);
    } with Map.fold(add, fullMap, res);

function updPrice(
  const tokenSet        : set(tokenId);
  var operations        : list(operation);
  var priceFeedProxy    : address)
                        : list(operation) is
  block {
    function oneTokenUpd(
      var param         : oneTokenUpdParam;
      const tokenId     : nat)
                        : oneTokenUpdParam is
      block {
        param.operations := Tezos.transaction(
          GetPrice(tokenId),
          0mutez,
          getProxyContract(param.priceFeedProxy)
        ) # param.operations
      } with param;
      var res : oneTokenUpdParam := Set.fold(
        oneTokenUpd,
        tokenSet,
        record[operations = operations; priceFeedProxy = priceFeedProxy]
      );
  } with res.operations

function calculateMaxCollaterallInUSD(
  var userAccount       : account;
  var params            : calcCollParams)
                        : nat is
  block {
    function oneToken(
      var param         : calcCollParams;
      var tokenId       : tokenId)
                        : calcCollParams is
      block {
        var token : tokenInfo := getTokenInfo(tokenId, param.s);
        param.res := param.res + (token.lastPrice * token.reserveFactor);
      } with param;
    var result : calcCollParams := Set.fold(
      oneToken,
      userAccount.markets,
      params
    );
  } with result.res

function calculateOutstandingBorrowInUSD(
  var userAccount       : account;
  var params            : calcCollParams)
                        : nat is
  block {
    function oneToken(
      var param         : calcCollParams;
      const borrowMap   : tokenId * nat)
                        : calcCollParams is
      block {
        var token : tokenInfo := getTokenInfo(borrowMap.0, param.s);
        param.res := param.res + (borrowMap.1 * token.lastPrice);
      } with param;
    var result : calcCollParams := Map.fold(
      oneToken,
      userAccount.borrowAmount,
      params
    );
  } with result.res

function updateInterest(
  var tokenId           : nat;
  var s                 : tokenStorage)
                        : tokenStorage is
  block {
    var token : tokenInfo := getTokenInfo(tokenId, s);
    if token.lastUpdateTime = Tezos.now
    then failwith("yToken/simular-time")
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

function updInterests(
  const setOfTokens     : set(tokenId);
  var s                 : tokenStorage)
                        : tokenStorage is
  block {
    function updInterest(
      var s             : tokenStorage;
      const tokenId     : tokenId)
                        : tokenStorage is
      updateInterest(tokenId, s);
  } with Set.fold(updInterest, setOfTokens, s)

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
            mintTokens := mainParams.amount * token.totalSupply * accuracy /
              abs(token.totalLiquid + token.totalBorrows - token.totalReserves);
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
          then failwith("yToken/token-taken-as-collateral")
          else skip;

          var userBalance : nat := getMapInfo(
            accountUser.balances,
            mainParams.tokenId
          );
          var token : tokenInfo := getTokenInfo(mainParams.tokenId, s);

          const liquidity : nat = abs(
            token.totalLiquid + token.totalBorrows - token.totalReserves
          );

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
      | _               -> skip
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
          var accountUser : account := getAccount(Tezos.sender, s);
          operations := Tezos.transaction(
            EnsuredBorrow(mainParams),
            0mutez,
            getEnsuredBorrowEntrypoint(this)
          ) # operations;
          var borrowSet : set(tokenId) := addToSet(accountUser.borrowAmount);
          var marketSet : set(tokenId) := Set.add(
            mainParams.tokenId,
            accountUser.markets
          );
          operations := updPrice(
            borrowSet,
            operations,
            s.priceFeedProxy
          );
          operations := updPrice(
            marketSet,
            operations,
            s.priceFeedProxy
          );
        }
      | _               -> skip
      end
  } with (operations, s)

function ensuredBorrow(
  const p               : useAction;
  var s                 : tokenStorage;
  const this            : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        EnsuredBorrow(mainParams) -> {
          if Tezos.sender =/= this
          then failwith("yToken/not-self-address")
          else skip;

          s := updateInterest(mainParams.tokenId, s);
          var token : tokenInfo := getTokenInfo(mainParams.tokenId, s);

          if token.totalLiquid < mainParams.amount
          then failwith("yToken/amount-too-big")
          else skip;

          var accountUser : account := getAccount(Tezos.sender, s);

          var maxBorrowInUSD : nat := calculateMaxCollaterallInUSD(
            accountUser,
            record[s = s; res = 0n; userAccount = accountUser]
          );
          var outstandingBorrowInUSD : nat := calculateOutstandingBorrowInUSD(
            accountUser,
            record[s = s; res = 0n; userAccount = accountUser]
          );
          var availableToBorrowInXtz : nat := abs(
            maxBorrowInUSD - outstandingBorrowInUSD
          );
          var maxBorrowXAmount : nat := availableToBorrowInXtz / token.lastPrice;

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

          const borrowAmount : nat = mainParams.amount * accuracy;

          userBorrowAmount := userBorrowAmount + borrowAmount;

          if maxBorrowXAmount > userBorrowAmount
          then failwith("yToken/more-then-available-borrow")
          else skip;

          lastBorrowIndex := token.borrowIndex;
          accountUser.borrowAmount[mainParams.tokenId] := userBorrowAmount;
          accountUser.lastBorrowIndex[mainParams.tokenId] := lastBorrowIndex;
          s.accountInfo[Tezos.sender] := accountUser;
          token.totalBorrows := token.totalBorrows + borrowAmount;
          token.totalLiquid := abs(token.totalLiquid - borrowAmount);
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
          var repayAmount : nat := mainParams.amount * accuracy;

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
          then failwith("yToken/amount-should-be-less-or-equal")
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

          var value : nat := 0n;

          if repayAmount - (repayAmount / accuracy * accuracy) > 0
          then value := repayAmount / accuracy + 1n
          else value := repayAmount / accuracy;

          operations := list [
            Tezos.transaction(
              TransferOutside(record [
                from_ = Tezos.sender;
                to_ = this;
                value = value
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
          var accountBorrower : account := getAccount(
            liquidateParams.borrower,
            s
          );
          operations := Tezos.transaction(
            EnsuredLiquidate(liquidateParams),
            0mutez,
            getEnsuredLiquidateEntrypoint(this)
          ) # operations;
          operations := updPrice(
            accountBorrower.markets,
            operations,
            s.priceFeedProxy
          );
        }
      | _                         -> skip
      end
  } with (operations, s)

function ensuredLiquidate(
  const p               : useAction;
  var s                 : tokenStorage;
  const this            : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        EnsuredLiquidate(liquidateParams) -> {
          s := updateInterest(liquidateParams.borrowToken, s);

          if Tezos.sender = liquidateParams.borrower
          then failwith("yToken/borrower-cannot-be-liquidator")
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
          var maxBorrowInUSD : nat := calculateMaxCollaterallInUSD(
            accountBorrower,
            record[s = s; res = 0n; userAccount = accountBorrower]
          );
          var outstandingBorrowInUSD : nat := calculateOutstandingBorrowInUSD(
            accountBorrower,
            record[s = s; res = 0n; userAccount = accountBorrower]
          );

          if outstandingBorrowInUSD > maxBorrowInUSD
          then skip
          else failwith("yToken/liquidatino-not-achieved");

          if borrowerBorrowAmount = 0n
          then failwith("yToken/debt-is-zero");
          else skip;

          var liquidateAmount : nat := liquidateParams.amount;

          if borrowerLastBorrowIndex =/= 0n
          then borrowerBorrowAmount := borrowerBorrowAmount *
            borrowToken.borrowIndex /
            borrowerLastBorrowIndex;
          else skip;

          if borrowerBorrowAmount < liquidateAmount
          then failwith("yToken/amount-should-be-less-or-equal")
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

          var liquidatorAccount : account := getAccount(
            Tezos.sender,
            s
          );

          var borrowerBalance : nat := getMapInfo(
            accountBorrower.balances,
            liquidateParams.collateralToken
          );
          var liquidatorBalance : nat := getMapInfo(
            liquidatorAccount.balances,
            liquidateParams.collateralToken
          );

          if borrowerBalance < seizeTokensFloat
          then failwith("yToken/seize/not-enough-tokens")
          else skip;

          borrowerBalance := abs(borrowerBalance - seizeTokensFloat);
          liquidatorBalance := liquidatorBalance + seizeTokensFloat;

          accountBorrower.balances[
            liquidateParams.collateralToken
          ] := borrowerBalance;
          liquidatorAccount.balances[
            liquidateParams.collateralToken
          ] := liquidatorBalance;
          s.accountInfo[liquidateParams.borrower] := accountBorrower;
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
          then failwith("yToken/not-enough-tokens-for-enter");
          else skip;

          if cardinal + 1n > maxMarkets
          then failwith("yToken/max-market-limit");
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
  const this            : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        ExitMarket(tokenId) -> {
          var userAccount : account := getAccount(Tezos.sender,s);
          var borrowSet : set(tokenId) := addToSet(userAccount.borrowAmount);
          s := updInterests(userAccount.markets, s);
          s := updInterests(borrowSet, s);
          operations := Tezos.transaction(
            EnsuredExitMarket(tokenId),
            0mutez,
            getEnsuredExitMarketEntrypoint(this)
          ) # operations;
          operations := updPrice(
            userAccount.markets,
            operations,
            s.priceFeedProxy
          );
        }
      | _                         -> skip
      end
  } with (operations, s)

function ensuredExitMarket(
  const p               : useAction;
  var s                 : tokenStorage;
  const this            : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        EnsuredExitMarket(tokenId) -> {
          if Tezos.sender =/= this
          then failwith("yToken/not-self-address")
          else skip;

          var userAccount : account := getAccount(Tezos.sender,s);
          userAccount.markets := Set.remove(tokenId, userAccount.markets);

          var maxBorrowInUSD : nat := calculateMaxCollaterallInUSD(
            userAccount,
            record[s = s; res = 0n; userAccount = userAccount]
          );
          var outstandingBorrowInUSD : nat := calculateOutstandingBorrowInUSD(
            userAccount,
            record[s = s; res = 0n; userAccount = userAccount]
          );

          if outstandingBorrowInUSD < maxBorrowInUSD
          then s.accountInfo[Tezos.sender] := userAccount;
          else failwith("yToken/debt-not-repaid");
        }
      | _                         -> skip
      end
  } with (operations, s)

function updatePrice(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
      case p of
        UpdatePrice(mainParams) -> {
          var token : tokenInfo := getTokenInfo(
            mainParams.tokenId,
            s
          );
          token.lastPrice := mainParams.amount;
          s.tokenInfo[mainParams.tokenId] := token;
        }
      | _                         -> skip
      end
  } with (noOperations, s)
