#include "./FA2Methods.ligo"
#include "./AdminMethods.ligo"
(*TODO: use the postfix Float in names of the var's that are multiplied by accuracy *)
function zeroCheck(
  const amt             : nat)
                        : unit is
    if amt = 0n
    then failwith("yToken/amount-is-zero");
    else unit


[@inline] function getEnsuredInterestEntrypoint(
  const selfAddress     : address)
                        : contract(entryAction) is
  case (
    Tezos.get_entrypoint_opt("%ensuredUpdateInterest", selfAddress)
                        : option(contract(entryAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("yToken/cant-get-ensuredInterest")
                        : contract(entryAction)
    )
  end;

[@inline] function getProxyContract(
  const priceFeedProxy  : address)
                        : contract(proxyAction) is
  case(
    Tezos.get_entrypoint_opt("%proxyUse", priceFeedProxy)
                        : option(contract(proxyAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("yToken/cant-get-contract-proxy") : contract(proxyAction)
    )
  end;

[@inline] function geteRateContract(
  const rateAddress     : address)
                        : contract(rateAction) is
  case(
    Tezos.get_entrypoint_opt("%rateUse", rateAddress)
                        : option(contract(rateAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("yToken/cant-get-interestRate-contract") : contract(rateAction)
    )
  end;

[@inline] function getUpdateBorrowRateContract(
  const selfAddress     : address)
                        : contract(mainParams) is
  case(
    Tezos.get_entrypoint_opt("%updateBorrowRate", selfAddress)
                        : option(contract(mainParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("yToken/cant-get-borrowRate") : contract(mainParams)
    )
  end;

[@inline] function getBorrowRateContract(
  const rateAddress     : address)
                        : contract(rateAction) is
  case(
    Tezos.get_entrypoint_opt("%getBorrowRate", rateAddress)
                        : option(contract(rateAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("yToken/cant-get-interestRate-contract") : contract(rateAction)
    )
  end;

function convertToSet(
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

function prepareOracleRequests(
  const tokenSet        : set(tokenId);
  var operations        : list(operation);
  const priceFeedProxy  : address)
                        : list(operation) is
  block {
    function oneTokenUpd(
      var operations    : list(operation);
      const tokenId     : nat)
                        : list(operation) is
      block {
        operations := Tezos.transaction(
          GetPrice(tokenId),
          0mutez,
          getProxyContract(priceFeedProxy)
        ) # operations
      } with operations;
      operations := Set.fold(
        oneTokenUpd,
        tokenSet,
        operations
      );
  } with operations

function calculateMaxCollaterallInCU(
  const userAccount     : account;
  var params            : calcCollParams)
                        : nat is
  block {
    function oneToken(
      var param         : calcCollParams;
      var tokenId       : tokenId)
                        : calcCollParams is
      block {
        var userBalance : nat := getMapInfo(
          userAccount.balances,
          tokenId
        );
        var token : tokenInfo := getTokenInfo(tokenId, param.s);
        (* sum += collateralFactor * exchangeRate * oraclePrice * balance *)
        param.res := param.res + userBalance * token.lastPrice * token.collateralFactor
          * abs(token.totalLiquid + token.totalBorrows - token.totalReserves)
          / token.totalSupply / accuracy;
      } with param;
    const result : calcCollParams = Set.fold(
      oneToken,
      userAccount.markets,
      params
    );
  } with result.res

function calculateOutstandingBorrowInCU(
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
        (* sum += oraclePrice * balance *)
        param.res := param.res + (borrowMap.1 * token.lastPrice);
      } with param;
    const result : calcCollParams = Map.fold(
      oneToken,
      userAccount.borrows,
      params
    );
  } with result.res

function updateInterest(
  const tokenId         : nat;
  const s               : fullTokenStorage)
                        : fullReturn is
    block {
      var token : tokenInfo := getTokenInfo(tokenId, s.storage);

      var operations : list(operation) := list[
        Tezos.transaction(
          GetBorrowRate(record[
            tokenId = tokenId;
            borrows = token.totalBorrows;
            cash = token.totalLiquid;
            reserves = token.totalReserves;
            (* TODO: lets send the response directly to ensuredUpdateInterest *)
            contract = getUpdateBorrowRateContract(Tezos.self_address);
          ]),
          0mutez,
          getBorrowRateContract(token.interstRateModel)
        );
        Tezos.transaction(
          EnsuredUpdateInterest(tokenId),
          0mutez,
          getEnsuredInterestEntrypoint(Tezos.self_address)
        );
      ];
    } with (operations, s)

function ensuredUpdateInterest(
  const tokenId         : nat;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    (* TODO: check the sender *)
    var token : tokenInfo := getTokenInfo(tokenId, s.storage);
    const borrowRate : nat = token.borrowRate;

    if borrowRate >= token.maxBorrowRate
    then failwith("yToken/borrow-rate-is-absurdly-high");
    else skip;

    //  Calculate the number of blocks elapsed since the last accrual
    const blockDelta : nat = abs(Tezos.now - token.lastUpdateTime);

    const simpleInterestFactorMantissa : nat = borrowRate * blockDelta;
    const interestAccumulatedMantissa : nat = simpleInterestFactorMantissa *
      token.totalBorrows / accuracy;

    token.totalBorrows := interestAccumulatedMantissa + token.totalBorrows;
    // one mult operation with float require accuracy division
    token.totalReserves := interestAccumulatedMantissa * token.reserveFactor /
      accuracy + token.totalReserves;
    // one mult operation with float require accuracy division
    token.borrowIndex := simpleInterestFactorMantissa * token.borrowIndex /
      accuracy + token.borrowIndex;
    token.lastUpdateTime := Tezos.now;

    s.storage.tokenInfo[tokenId] := token;
  } with (noOperations, s)

function verifyUpdatedRates(
  const setOfTokens     : set(tokenId);
  var s                 : tokenStorage)
                        : tokenStorage is
  block {
    function updInterest(
      var s             : tokenStorage;
      const tokenId     : tokenId)
                        : tokenStorage is
      block {
        var token : tokenInfo := getTokenInfo(tokenId, s);
        if token.lastUpdateTime =/= Tezos.now
        then failwith("yToken/need-update-interestRate")
        else skip;
      } with s
  } with Set.fold(updInterest, setOfTokens, s)

function verifyUpdatedPrices(
  const setOfTokens     : set(tokenId);
  var s                 : tokenStorage)
                        : tokenStorage is
  block {
    function updInterest(
      var s             : tokenStorage;
      const tokenId     : tokenId)
                        : tokenStorage is
      block {
        var token : tokenInfo := getTokenInfo(tokenId, s);
        if token.priceUpdateTime =/= Tezos.now
        then failwith("yToken/need-update-price")
        else skip;
      } with s
  } with Set.fold(updInterest, setOfTokens, s)

function mint(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Mint(mainParams) -> {
          zeroCheck(mainParams.amount);

          var mintTokensMantissa : nat := mainParams.amount * accuracy;
          var token : tokenInfo := getTokenInfo(mainParams.tokenId, s);

          if token.totalSupply =/= 0n
          then block {
            if token.lastUpdateTime =/= Tezos.now
            then failwith("yToken/need-update-interestRate")
            else skip;

            mintTokensMantissa := mintTokensMantissa * token.totalSupply /
              abs(token.totalLiquid + token.totalBorrows - token.totalReserves);
          }
          else skip;

          var userAccount : account := getAccount(Tezos.sender, s);
          var userBalance : nat := getMapInfo(
            userAccount.balances,
            mainParams.tokenId
          );

          userBalance := userBalance + mintTokensMantissa;

          userAccount.balances[mainParams.tokenId] := userBalance;
          s.accountInfo[Tezos.sender] := userAccount;
          token.totalSupply := token.totalSupply + mintTokensMantissa;
          token.totalLiquid := token.totalLiquid + mainParams.amount * accuracy;
          s.tokenInfo[mainParams.tokenId] := token;

          operations := list [
              case token.faType of
              | FA12 -> Tezos.transaction(
                  TransferOutside(record [
                    from_ = Tezos.sender;
                    to_ = Tezos.self_address;
                    value = mainParams.amount
                  ]),
                  0mutez,
                  getTokenContract(token.mainToken)
                )
              | FA2(assetId) -> Tezos.transaction(
                  IterateTransferOutside(record [
                    from_ = Tezos.sender;
                    txs = list[
                      record[
                        tokenId = assetId;
                        to_ = Tezos.self_address;
                        amount = mainParams.amount
                      ]
                    ]
                  ]),
                  0mutez,
                  getIterTranserContract(token.mainToken)
                )
              end
          ];
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
        Redeem(mainParams) -> {
          zeroCheck(mainParams.amount);

          var token : tokenInfo := getTokenInfo(mainParams.tokenId, s);

          if token.lastUpdateTime =/= Tezos.now
          then failwith("yToken/need-update-interestRate")
          else skip;

          var accountUser : account := getAccount(Tezos.sender, s);

          if Set.mem(mainParams.tokenId, accountUser.markets)
          then failwith("yToken/token-taken-as-collateral")
          else skip;

          var userBalance : nat := getMapInfo(
            accountUser.balances,
            mainParams.tokenId
          );

          const liquidity : nat = abs(
            token.totalLiquid + token.totalBorrows - token.totalReserves
          );

          const redeemAmount : nat = if mainParams.amount = 0n
          then userBalance * liquidity / token.totalSupply / accuracy
          else mainParams.amount;

          if token.totalLiquid < redeemAmount

          then failwith("yToken/not-enough-liquid")
          else skip;

          var burnTokensMantissa : nat := redeemAmount * accuracy *
            token.totalSupply / liquidity;
          if userBalance < burnTokensMantissa
          then failwith("yToken/not-enough-tokens-to-burn")
          else skip;

          userBalance := abs(userBalance - burnTokensMantissa);
          accountUser.balances[mainParams.tokenId] := userBalance;
          s.accountInfo[Tezos.sender] := accountUser;
          token.totalSupply := abs(token.totalSupply - burnTokensMantissa);
          token.totalLiquid := abs(token.totalLiquid - redeemAmount *
            accuracy);
          s.tokenInfo[mainParams.tokenId] := token;

          operations := list [
              case token.faType of
              | FA12 -> Tezos.transaction(
                  TransferOutside(record [
                    from_ = Tezos.self_address;
                    to_ = Tezos.sender;
                    value = redeemAmount
                  ]),
                  0mutez,
                  getTokenContract(token.mainToken)
                )
              | FA2(assetId) -> Tezos.transaction(
                  IterateTransferOutside(record [
                    from_ = Tezos.self_address;
                    txs = list[
                      record[
                        tokenId = assetId;
                        to_ = Tezos.sender;
                        amount = redeemAmount
                      ]
                    ]
                  ]),
                  0mutez,
                  getIterTranserContract(token.mainToken)
                )
              end
          ];
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
        Borrow(mainParams) -> {
          zeroCheck(mainParams.amount);

          var accountUser : account := getAccount(Tezos.sender, s);

          const borrowSet : set(tokenId) = convertToSet(accountUser.borrows);
          const marketSet : set(tokenId) = accountUser.markets;

          s := verifyUpdatedRates(marketSet, s);
          s := verifyUpdatedRates(borrowSet, s);
          s := verifyUpdatedPrices(marketSet, s);
          s := verifyUpdatedPrices(borrowSet, s);

          var token : tokenInfo := getTokenInfo(mainParams.tokenId, s);

          if token.lastUpdateTime =/= Tezos.now
          then failwith("yToken/need-update-interestRate")
          else skip;
          if token.totalLiquid < mainParams.amount
          then failwith("yToken/amount-too-big")
          else skip;

          const maxBorrowInCU : nat = calculateMaxCollaterallInCU(
            accountUser,
            record[s = s; res = 0n; userAccount = accountUser]
          );
          const outstandingBorrowInCU : nat = calculateOutstandingBorrowInCU(
            accountUser,
            record[s = s; res = 0n; userAccount = accountUser]
          );
          const availableToBorrowInCU : nat = abs(
            maxBorrowInCU - outstandingBorrowInCU
          );
          const maxBorrowXAmount : nat = availableToBorrowInCU / token.lastPrice;

          var userBorrowAmount : nat := getMapInfo(
            accountUser.borrows,
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

          const borrowsMatissa : nat = mainParams.amount * accuracy;

          if maxBorrowXAmount > borrowsMatissa
          then failwith("yToken/more-then-available-borrow")
          else skip;

          userBorrowAmount := userBorrowAmount + borrowsMatissa;

          lastBorrowIndex := token.borrowIndex;
          accountUser.borrows[mainParams.tokenId] := userBorrowAmount;
          accountUser.lastBorrowIndex[mainParams.tokenId] := lastBorrowIndex;
          s.accountInfo[Tezos.sender] := accountUser;

          token.totalBorrows := token.totalBorrows + borrowsMatissa;
          token.totalLiquid := abs(token.totalLiquid - borrowsMatissa);

          s.tokenInfo[mainParams.tokenId] := token;

          operations := list [
              case token.faType of
              | FA12 -> Tezos.transaction(
                  TransferOutside(record [
                    from_ = Tezos.self_address;
                    to_ = Tezos.sender;
                    value = mainParams.amount
                  ]),
                  0mutez,
                  getTokenContract(token.mainToken)
                )
              | FA2(assetId) -> Tezos.transaction(
                  IterateTransferOutside(record [
                    from_ = Tezos.self_address;
                    txs = list[
                      record[
                        tokenId = assetId;
                        to_ = Tezos.sender;
                        amount = mainParams.amount
                      ]
                    ]
                  ]),
                  0mutez,
                  getIterTranserContract(token.mainToken)
                )
              end
          ];
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
        Repay(mainParams) -> {
          zeroCheck(mainParams.amount);

          var token : tokenInfo := getTokenInfo(mainParams.tokenId, s);

          if token.lastUpdateTime =/= Tezos.now
          then failwith("yToken/need-update-interestRate")
          else skip;

          var repayAmountMantissa : nat := mainParams.amount * accuracy;

          var accountUser : account := getAccount(Tezos.sender, s);
          var lastBorrowIndex : nat := getMapInfo(
            accountUser.lastBorrowIndex,
            mainParams.tokenId
          );
          var userBorrowAmount : nat := getMapInfo(
            accountUser.borrows,
            mainParams.tokenId
          );

          if lastBorrowIndex =/= 0n
          then userBorrowAmount := userBorrowAmount *
            token.borrowIndex / lastBorrowIndex;
          else skip;

          if repayAmountMantissa = 0n
          then repayAmountMantissa := userBorrowAmount;
          else skip;

          if userBorrowAmount <= repayAmountMantissa

          then failwith("yToken/amount-should-be-less-or-equal")
          else skip;

          userBorrowAmount := abs(
            userBorrowAmount - repayAmountMantissa
          );
          lastBorrowIndex := token.borrowIndex;

          accountUser.lastBorrowIndex[mainParams.tokenId] := lastBorrowIndex;
          accountUser.borrows[mainParams.tokenId] := userBorrowAmount;
          s.accountInfo[Tezos.sender] := accountUser;
          token.totalBorrows := abs(token.totalBorrows - repayAmountMantissa);
          s.tokenInfo[mainParams.tokenId] := token;

          var value : nat := 0n;

          if repayAmountMantissa - (repayAmountMantissa / accuracy * accuracy) > 0
          then value := repayAmountMantissa / accuracy + 1n
          else value := repayAmountMantissa / accuracy;

          operations := list [
              case token.faType of
              | FA12 -> Tezos.transaction(
                  TransferOutside(record [
                    from_ = Tezos.sender;
                    to_ = Tezos.self_address;
                    value = value
                  ]),
                  0mutez,
                  getTokenContract(token.mainToken)
                )
              | FA2(assetId) -> Tezos.transaction(
                  IterateTransferOutside(record [
                    from_ = Tezos.self_address;
                    txs = list[
                      record[
                        tokenId = assetId;
                        to_ = Tezos.self_address;
                        amount = value
                      ]
                    ]
                  ]),
                  0mutez,
                  getIterTranserContract(token.mainToken)
                )
              end
          ];
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
        Liquidate(liquidateParams) -> {
          zeroCheck(liquidateParams.amount);

          var accountBorrower : account := getAccount(
            liquidateParams.borrower,
            s
          );
          var borrowSet : set(tokenId) := convertToSet(accountBorrower.borrows);
          var marketSet : set(tokenId) := accountBorrower.markets;

          s := verifyUpdatedRates(marketSet, s);
          s := verifyUpdatedRates(borrowSet, s);
          s := verifyUpdatedPrices(marketSet, s);
          s := verifyUpdatedPrices(borrowSet, s);

          var borrowToken : tokenInfo := getTokenInfo(
            liquidateParams.borrowToken,
            s
          );

          if Tezos.sender = liquidateParams.borrower
          then failwith("yToken/borrower-cannot-be-liquidator")
          else skip;

          var borrowerBorrowAmount : nat := getMapInfo(
            accountBorrower.borrows,
            liquidateParams.borrowToken
          );
          var borrowerLastBorrowIndex : nat := getMapInfo(
            accountBorrower.lastBorrowIndex,
            liquidateParams.borrowToken
          );

          const maxBorrowInCU : nat = calculateMaxCollaterallInCU(
            accountBorrower,
            record[s = s; res = 0n; userAccount = accountBorrower]
          );
          const outstandingBorrowInCU : nat = calculateOutstandingBorrowInCU(
          
            accountBorrower,
            record[s = s; res = 0n; userAccount = accountBorrower]
          );

          if outstandingBorrowInCU > maxBorrowInCU
          then skip
          else failwith("yToken/liquidation-not-achieved");
          if borrowerBorrowAmount = 0n
          then failwith("yToken/debt-is-zero");
          else skip;

          var liqAmountMantissa : nat := liquidateParams.amount * accuracy;

          if borrowerLastBorrowIndex =/= 0n
          then borrowerBorrowAmount := borrowerBorrowAmount *
            borrowToken.borrowIndex /
            borrowerLastBorrowIndex;
          else skip;

          (* liquidate amount can't be more than allowed close factor *)
          const maxClose : nat = borrowerBorrowAmount * s.closeFactor
            / accuracy;

          if liqAmountMantissa <= maxClose
          then skip
          else failwith("yToken/too-much-repay");

          borrowerBorrowAmount := abs(
            borrowerBorrowAmount - liqAmountMantissa
          );
          borrowerLastBorrowIndex := borrowToken.borrowIndex;
          borrowToken.totalBorrows := abs(
            borrowToken.totalBorrows - liqAmountMantissa
          );

          accountBorrower.lastBorrowIndex[
            liquidateParams.borrowToken
          ] := borrowerLastBorrowIndex;
          accountBorrower.borrows[
            liquidateParams.borrowToken
          ] := borrowerBorrowAmount;

          operations := list [
              case borrowToken.faType of
              | FA12 -> Tezos.transaction(
                  TransferOutside(record [
                    from_ = Tezos.sender;
                    to_ = Tezos.self_address;
                    value = liqAmountMantissa
                  ]),
                  0mutez,
                  getTokenContract(borrowToken.mainToken)
                )
              | FA2(assetId) -> Tezos.transaction(
                  IterateTransferOutside(record [
                    from_ = Tezos.self_address;
                    txs = list[
                      record[
                        tokenId = assetId;
                        to_ = Tezos.self_address;
                        amount = liqAmountMantissa
                      ]
                    ]
                  ]),
                  0mutez,
                  getIterTranserContract(borrowToken.mainToken)
                )
              end
          ];

          if accountBorrower.markets contains liquidateParams.collateralToken
          then skip
          else failwith("yToken/collateralToken-not-contains-in-borrow-market");


          var collateralToken : tokenInfo := getTokenInfo(
            liquidateParams.collateralToken,
            s
          );

          (* seizeAmount = actualRepayAmount * liquidationIncentive * priceBorrowed / priceCollateral
           seizeTokens = seizeAmount / exchangeRate *)
          const exchangeRateFloat : nat = abs(
            collateralToken.totalLiquid + collateralToken.totalBorrows -
              collateralToken.totalReserves
          ) * accuracy / collateralToken.totalSupply;
          const seizeTokensFloat : nat = liqAmountMantissa * s.liqIncentive
            * borrowToken.lastPrice /
            exchangeRateFloat / collateralToken.lastPrice;

          var liquidatorAccount : account := getAccount(
            Tezos.sender,
            s
          );

          var borrowerBalance : nat := getMapInfo(
            accountBorrower.balances,
            liquidateParams.collateralToken
          );

          if borrowerBalance < seizeTokensFloat
          then failwith("yToken/seize/not-enough-tokens")
          else skip;

          var liquidatorBalance : nat := getMapInfo(
            liquidatorAccount.balances,
            liquidateParams.collateralToken
          );
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
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        EnterMarket(tokenId) -> {
          var userAccount : account := getAccount(Tezos.sender, s);
          (* TODO: no need to define the const that is used in the only place;
          call Set.size operator in the if-else constraction *)
          const cardinal : nat = Set.size(userAccount.markets);

          (* TODO: move maxMarkets to storage; allow the admin to configure it *)
          if cardinal >= maxMarkets
          then failwith("yToken/max-market-limit");
          else skip;

          userAccount.markets := Set.add(tokenId, userAccount.markets);
          s.accountInfo[Tezos.sender] := userAccount;
        }
      | _                         -> skip
      end
  } with (operations, s)

function exitMarket(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        ExitMarket(tokenId) -> {
          var userAccount : account := getAccount(Tezos.sender, s);
          var borrowSet : set(tokenId) := convertToSet(userAccount.borrows);

          s := verifyUpdatedRates(userAccount.markets, s);
          s := verifyUpdatedRates(borrowSet, s);
          s := verifyUpdatedPrices(userAccount.markets, s);
          s := verifyUpdatedPrices(borrowSet, s);

          userAccount.markets := Set.remove(tokenId, userAccount.markets);
          const maxBorrowInCU : nat = calculateMaxCollaterallInCU(
            userAccount,
            record[s = s; res = 0n; userAccount = userAccount]
          );
          const outstandingBorrowInCU : nat = calculateOutstandingBorrowInCU(
            userAccount,
            record[s = s; res = 0n; userAccount = userAccount]
          );

          if outstandingBorrowInCU < maxBorrowInCU
          then s.accountInfo[Tezos.sender] := userAccount;
          else failwith("yToken/debt-not-repaid");
        }
      | _                         -> skip
      end
  } with (operations, s)

function returnPrice(
  const params          : mainParams;
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

function updateBorrowRate(
  const params          : mainParams;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    if Tezos.sender =/= Tezos.self_address
    then failwith("yToken/permition-error");
    else skip;

    var token : tokenInfo := getTokenInfo(
      params.tokenId,
      s.storage
    );
    token.borrowRate := params.amount;
    s.storage.tokenInfo[params.tokenId] := token;
  } with (noOperations, s)

function getReserveFactor(
  const tokenId         : tokenId;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    var token : tokenInfo := getTokenInfo(tokenId, s.storage);

    if Tezos.sender =/= token.interstRateModel
    then failwith("yToken/permition-error");
    else skip;

    const operations : list(operation) = list [
      Tezos.transaction(
        UpdReserveFactor(token.reserveFactor),
        0mutez,
        geteRateContract(token.interstRateModel)
      )
    ];
  } with (operations, s)

function updatePrice(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        UpdatePrice(tokenSet) -> {
          operations := prepareOracleRequests(
            tokenSet,
            operations,
            s.priceFeedProxy
          )
        }
      | _                         -> skip
      end
  } with (operations, s)