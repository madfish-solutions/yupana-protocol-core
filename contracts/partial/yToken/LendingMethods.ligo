#include "./FA2Methods.ligo"
#include "./AdminMethods.ligo"
(*TODO: use the postfix Float in names of the var's that are multiplied by accuracy *)
function zeroCheck(
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

function verifyTokenUpdated(
    const token         : tokenInfo)
                        : unit is
    if token.lastUpdateTime < Tezos.now or token.priceUpdateTime < Tezos.now
    then failwith("yToken/need-update")
    else unit;

function calculateMaxCollaterallInCU(
  const userAccount     : account;
  var params            : calcCollParams)
                        : nat is
  block {
    function oneToken(
      var param         : calcCollParams;
      const tokenId     : tokenId)
                        : calcCollParams is
      block {
        const userBalance : nat = getMapInfo(
          userAccount.balances,
          tokenId
        );
        const token : tokenInfo = getTokenInfo(tokenId, param.s);

        verifyTokenUpdated(token);

        (* sum += collateralFactor * exchangeRate * oraclePrice * balance *)
        param.res := param.res + ((userBalance * token.lastPrice * token.collateralFactor)
          * (abs(token.totalLiquid + token.totalBorrows - token.totalReserves)
          / token.totalSupply) / accuracy);
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
        const token : tokenInfo = getTokenInfo(borrowMap.0, param.s);

        verifyTokenUpdated(token);

        (* sum += oraclePrice * balance *)
        param.res := param.res + ((borrowMap.1 * token.lastPrice) / accuracy);
      } with param;
    const result : calcCollParams = Map.fold(
      oneToken,
      userAccount.borrows,
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

      if _token.totalBorrows = 0n
      then block {
        _token.lastUpdateTime := Tezos.now;
        s.storage.tokenInfo[tokenId] := _token;
      }
      else operations := list[
        Tezos.transaction(
          record[
            tokenId = tokenId;
            borrows = _token.totalBorrows;
            cash = _token.totalLiquid;
            reserves = _token.totalReserves;
            accuracy = accuracy;
            contract = getUpdateBorrowRateContract(Tezos.self_address);
          ],
          0mutez,
          getBorrowRateContract(_token.interstRateModel)
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
          zeroCheck(yAssetParams.amount);

          var mintTokensFloat : nat := yAssetParams.amount * accuracy;
          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s);

          if token.totalSupply =/= 0n
          then {
            verifyTokenUpdated(token);
            mintTokensFloat := mintTokensFloat * token.totalSupply /
              abs(token.totalLiquid + token.totalBorrows - token.totalReserves);
          } else skip;

          var userAccount : account := getAccount(Tezos.sender, s);
          var userBalanceFloat : nat := getMapInfo(
            userAccount.balances,
            yAssetParams.tokenId
          );

          userBalanceFloat := userBalanceFloat + mintTokensFloat;

          userAccount.balances[yAssetParams.tokenId] := userBalanceFloat;
          s.accountInfo[Tezos.sender] := userAccount;
          token.totalSupply := token.totalSupply + mintTokensFloat;
          token.totalLiquid := token.totalLiquid + yAssetParams.amount * accuracy;
          s.tokenInfo[yAssetParams.tokenId] := token;

          operations := list [
              case token.faType of
              | FA12 -> Tezos.transaction(
                  TransferOutside(record [
                    from_ = Tezos.sender;
                    to_ = Tezos.self_address;
                    value = yAssetParams.amount
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
                        amount = yAssetParams.amount
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
        Redeem(yAssetParams) -> {
          zeroCheck(yAssetParams.amount);

          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s);
          if token.lastUpdateTime < Tezos.now
          then failwith("yToken/need-update")
          else skip;

          var accountUser : account := getAccount(Tezos.sender, s);

          if Set.mem(yAssetParams.tokenId, accountUser.markets)
          then failwith("yToken/token-taken-as-collateral")
          else skip;

          var userBalanceFloat : nat := getMapInfo(
            accountUser.balances,
            yAssetParams.tokenId
          );

          const liquidity : nat = abs(
            token.totalLiquid + token.totalBorrows - token.totalReserves
          );

          const redeemAmount : nat = if yAssetParams.amount = 0n
          then userBalanceFloat * liquidity / token.totalSupply / accuracy
          else yAssetParams.amount;

          if token.totalLiquid < redeemAmount
          then failwith("yToken/not-enough-liquid")
          else skip;

          var burnTokensFloat : nat := redeemAmount * accuracy *
            token.totalSupply / liquidity;
          if userBalanceFloat < burnTokensFloat
          then failwith("yToken/not-enough-tokens-to-burn")
          else skip;

          userBalanceFloat := abs(userBalanceFloat - burnTokensFloat);
          accountUser.balances[yAssetParams.tokenId] := userBalanceFloat;
          s.accountInfo[Tezos.sender] := accountUser;
          token.totalSupply := abs(token.totalSupply - burnTokensFloat);
          token.totalLiquid := abs(token.totalLiquid - redeemAmount *
            accuracy);
          s.tokenInfo[yAssetParams.tokenId] := token;

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
        Borrow(yAssetParams) -> {
          zeroCheck(yAssetParams.amount);

          var accountUser : account := getAccount(Tezos.sender, s);
          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s);
          verifyTokenUpdated(token);

          if token.totalLiquid < yAssetParams.amount
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

          if outstandingBorrowInCU > maxBorrowInCU
          then failwith("yToken/exceeds-the-permissible-debt");
          else skip;

          const availableToBorrowInCU : nat = abs(
            maxBorrowInCU - outstandingBorrowInCU
          );
          const maxBorrowXAmount : nat = availableToBorrowInCU
            / token.lastPrice;

          var userBorrowAmountFloat : nat := getMapInfo(
            accountUser.borrows,
            yAssetParams.tokenId
          );
          var lastBorrowIndex : nat := getMapInfo(
            accountUser.lastBorrowIndex,
            yAssetParams.tokenId
          );

          if lastBorrowIndex =/= 0n
          then userBorrowAmountFloat := userBorrowAmountFloat *
              token.borrowIndex / lastBorrowIndex;
          else skip;

          const borrowsFloat : nat = yAssetParams.amount * accuracy;

          if maxBorrowXAmount > borrowsFloat
          then failwith("yToken/more-then-available-borrow")
          else skip;

          userBorrowAmountFloat := userBorrowAmountFloat + borrowsFloat;

          lastBorrowIndex := token.borrowIndex;
          accountUser.borrows[yAssetParams.tokenId] := userBorrowAmountFloat;
          accountUser.lastBorrowIndex[yAssetParams.tokenId] := lastBorrowIndex;
          s.accountInfo[Tezos.sender] := accountUser;
          token.totalBorrows := token.totalBorrows + borrowsFloat;
          token.totalLiquid := abs(token.totalLiquid - borrowsFloat);
          s.tokenInfo[yAssetParams.tokenId] := token;

          operations := list [
              case token.faType of
              | FA12 -> Tezos.transaction(
                  TransferOutside(record [
                    from_ = Tezos.self_address;
                    to_ = Tezos.sender;
                    value = yAssetParams.amount
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
                        amount = yAssetParams.amount
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
        Repay(yAssetParams) -> {

          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s);
          if token.lastUpdateTime < Tezos.now
          then failwith("yToken/need-update")
          else skip;

          var repayAmountFloat : nat := yAssetParams.amount * accuracy;

          var accountUser : account := getAccount(Tezos.sender, s);
          var lastBorrowIndex : nat := getMapInfo(
            accountUser.lastBorrowIndex,
            yAssetParams.tokenId
          );
          var userBorrowAmountFloat : nat := getMapInfo(
            accountUser.borrows,
            yAssetParams.tokenId
          );

          if repayAmountFloat = 0n
          then repayAmountFloat := userBorrowAmountFloat;
          else skip;

          if lastBorrowIndex =/= 0n
          then userBorrowAmountFloat := userBorrowAmountFloat *
            token.borrowIndex / lastBorrowIndex;
          else skip;

          if repayAmountFloat > userBorrowAmountFloat
          then failwith("yToken/amount-should-be-less-or-equal")
          else skip;

          userBorrowAmountFloat := abs(
            userBorrowAmountFloat - repayAmountFloat
          );
          lastBorrowIndex := token.borrowIndex;

          accountUser.lastBorrowIndex[yAssetParams.tokenId] := lastBorrowIndex;
          accountUser.borrows[yAssetParams.tokenId] := userBorrowAmountFloat;
          s.accountInfo[Tezos.sender] := accountUser;
          token.totalBorrows := abs(token.totalBorrows - repayAmountFloat);
          s.tokenInfo[yAssetParams.tokenId] := token;

          var value : nat := 0n;

          if repayAmountFloat - (repayAmountFloat / accuracy * accuracy) > 0
          then value := repayAmountFloat / accuracy + 1n
          else value := repayAmountFloat / accuracy;

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
          var borrowToken : tokenInfo := getTokenInfo(
            liquidateParams.borrowToken,
            s
          );

          if Tezos.sender = liquidateParams.borrower
          then failwith("yToken/borrower-cannot-be-liquidator")
          else skip;

          var borrowerBorrowAmountFloat : nat := getMapInfo(
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
          if borrowerBorrowAmountFloat = 0n
          then failwith("yToken/debt-is-zero");
          else skip;

          var liqAmountFloat : nat := liquidateParams.amount * accuracy;

          if borrowerLastBorrowIndex =/= 0n
          then borrowerBorrowAmountFloat := borrowerBorrowAmountFloat *
            borrowToken.borrowIndex /
            borrowerLastBorrowIndex;
          else skip;

          (* liquidate amount can't be more than allowed close factor *)
          const maxClose : nat = borrowerBorrowAmountFloat * s.closeFactor
            / accuracy;

          if liqAmountFloat <= maxClose
          then skip
          else failwith("yToken/too-much-repay");

          borrowerBorrowAmountFloat := abs(
            borrowerBorrowAmountFloat - liqAmountFloat
          );
          borrowerLastBorrowIndex := borrowToken.borrowIndex;
          borrowToken.totalBorrows := abs(
            borrowToken.totalBorrows - liqAmountFloat
          );

          accountBorrower.lastBorrowIndex[
            liquidateParams.borrowToken
          ] := borrowerLastBorrowIndex;
          accountBorrower.borrows[
            liquidateParams.borrowToken
          ] := borrowerBorrowAmountFloat;

          operations := list [
              case borrowToken.faType of
              | FA12 -> Tezos.transaction(
                  TransferOutside(record [
                    from_ = Tezos.sender;
                    to_ = Tezos.self_address;
                    value = liqAmountFloat
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
                        amount = liqAmountFloat
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
          const seizeTokensFloat : nat = liqAmountFloat * s.liqIncentive
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

          if Set.size(userAccount.markets) >= s.maxMarkets
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

          var token : tokenInfo := getTokenInfo(
            tokenId,
            s
          );
          verifyTokenUpdated(token);

          userAccount.markets := Set.remove(tokenId, userAccount.markets);
          const maxBorrowInCU : nat = calculateMaxCollaterallInCU(
            userAccount,
            record[s = s; res = 0n; userAccount = userAccount]
          );
          const outstandingBorrowInCU : nat = calculateOutstandingBorrowInCU(
            userAccount,
            record[s = s; res = 0n; userAccount = userAccount]
          );

          if outstandingBorrowInCU <= maxBorrowInCU or outstandingBorrowInCU = 0n
          then s.accountInfo[Tezos.sender] := userAccount;
          else failwith("yToken/debt-not-repaid");
        }
      | _                         -> skip
      end
  } with (operations, s)

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

    if Tezos.sender =/= token.interstRateModel
    then failwith("yToken/not-self-address")
    else skip;
    if borrowRate >= token.maxBorrowRate
    then failwith("yToken/borrow-rate-is-absurdly-high");
    else skip;

    //  Calculate the number of blocks elapsed since the last accrual
    const blockDelta : nat = abs(Tezos.now - token.lastUpdateTime);

    const simpleInterestFactor : nat = borrowRate * blockDelta;
    const interestAccumulated : nat = simpleInterestFactor *
      token.totalBorrows / accuracy;

    token.totalBorrows := interestAccumulated + token.totalBorrows;
    // one mult operation with float require accuracy division
    token.totalReserves := interestAccumulated * token.reserveFactor /
      accuracy + token.totalReserves;
    // one mult operation with float require accuracy division
    token.borrowIndex := simpleInterestFactor * token.borrowIndex /
      accuracy + token.borrowIndex;
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
        UpdReserveFactor(token.reserveFactor),
        0mutez,
        getReserveFactorContract(token.interstRateModel)
      )
    ];
  } with (operations, s)
