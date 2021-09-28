#include "./FA2Methods.ligo"
#include "./AdminMethods.ligo"

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

        (* sum += collateralFactorFloat * exchangeRate * oraclePrice * balance *)
        param.res := param.res + ((userBalance * token.lastPrice
          * token.collateralFactorFloat) * (abs(token.totalLiquidFloat
          + token.totalBorrowsFloat - token.totalReservesFloat)
          / token.totalSupplyFloat) / accuracy);
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
        param.res := param.res + ((borrowMap.1 * token.lastPrice));
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

          if yAssetParams.tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

          var mintTokensFloat : nat := yAssetParams.amount * accuracy;
          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s);

          if token.totalSupplyFloat =/= 0n
          then {
            verifyTokenUpdated(token);
            mintTokensFloat := mintTokensFloat * token.totalSupplyFloat /
              abs(token.totalLiquidFloat + token.totalBorrowsFloat
                - token.totalReservesFloat);
          } else skip;

          var userAccount : account := getAccount(Tezos.sender, s);
          var userBalanceFloat : nat := getMapInfo(
            userAccount.balances,
            yAssetParams.tokenId
          );

          userBalanceFloat := userBalanceFloat + mintTokensFloat;

          userAccount.balances[yAssetParams.tokenId] := userBalanceFloat;
          s.accountInfo[Tezos.sender] := userAccount;
          token.totalSupplyFloat := token.totalSupplyFloat + mintTokensFloat;
          token.totalLiquidFloat := token.totalLiquidFloat
            + yAssetParams.amount * accuracy;
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

          if yAssetParams.tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s);

          verifyTokenUpdated(token);

          var accountUser : account := getAccount(Tezos.sender, s);

          if Set.mem(yAssetParams.tokenId, accountUser.markets)
          then failwith("yToken/token-taken-as-collateral")
          else skip;

          var userBalanceFloat : nat := getMapInfo(
            accountUser.balances,
            yAssetParams.tokenId
          );
          (* TODO: rename to liquidityFloat *)
          const liquidity : nat = abs(token.totalLiquidFloat
            + token.totalBorrowsFloat - token.totalReservesFloat);

          const redeemAmount : nat = if yAssetParams.amount = 0n
          then userBalanceFloat * liquidity / token.totalSupplyFloat / accuracy
          else yAssetParams.amount;

          (* TODO: fix comparison redeemAmount isn't float but totalLiquidFloat is *)
          if redeemAmount > token.totalLiquidFloat
          then failwith("yToken/not-enough-liquid")
          else skip;

          var burnTokensFloat : nat := redeemAmount * accuracy *
            token.totalSupplyFloat / liquidity;
          if userBalanceFloat < burnTokensFloat
          then failwith("yToken/not-enough-tokens-to-burn")
          else skip;

          userBalanceFloat := abs(userBalanceFloat - burnTokensFloat);
          accountUser.balances[yAssetParams.tokenId] := userBalanceFloat;
          s.accountInfo[Tezos.sender] := accountUser;
          token.totalSupplyFloat := abs(token.totalSupplyFloat - burnTokensFloat);
          token.totalLiquidFloat := abs(token.totalLiquidFloat - redeemAmount *
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

          if yAssetParams.tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

          var accountUser : account := getAccount(Tezos.sender, s);
          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s);
          verifyTokenUpdated(token);

          const borrowsFloat : nat = yAssetParams.amount * accuracy;

          if borrowsFloat > token.totalLiquidFloat
          then failwith("yToken/amount-too-big")
          else skip;


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

          userBorrowAmountFloat := userBorrowAmountFloat + borrowsFloat;
          accountUser.borrows[yAssetParams.tokenId] := userBorrowAmountFloat;
          accountUser.lastBorrowIndex[yAssetParams.tokenId] := token.borrowIndex;
          s.accountInfo[Tezos.sender] := accountUser;

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

          token.totalBorrowsFloat := token.totalBorrowsFloat + borrowsFloat;
          token.totalLiquidFloat := abs(token.totalLiquidFloat - borrowsFloat);
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

          if yAssetParams.tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

          verifyTokenUpdated(token);

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

          if lastBorrowIndex =/= 0n
          then userBorrowAmountFloat := userBorrowAmountFloat *
            token.borrowIndex / lastBorrowIndex;
          else skip;

          if repayAmountFloat = 0n
          then repayAmountFloat := userBorrowAmountFloat;
          else skip;

          if repayAmountFloat > userBorrowAmountFloat
          then failwith("yToken/amount-should-be-less-or-equal")
          else skip;

          userBorrowAmountFloat := abs(
            userBorrowAmountFloat - repayAmountFloat
          );
          (* TODO: remove the next line and update
          accountUser.lastBorrowIndex[yAssetParams.tokenId] directly *)
          lastBorrowIndex := token.borrowIndex;
          accountUser.lastBorrowIndex[yAssetParams.tokenId] := lastBorrowIndex;
          accountUser.borrows[yAssetParams.tokenId] := userBorrowAmountFloat;
          s.accountInfo[Tezos.sender] := accountUser;
          token.totalBorrowsFloat := abs(token.totalBorrowsFloat
            - repayAmountFloat);
          (* TODO: increase the liquid amount of tokens *)
          s.tokenInfo[yAssetParams.tokenId] := token;

          var value : nat := 0n;

          (* TODO: save the gas; replace with ediv *)
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

          if liquidateParams.borrowToken < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined(borrowToken)");

          if liquidateParams.collateralToken < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined(collateralToken)");

          var accountBorrower : account := getAccount(
            liquidateParams.borrower,
            s
          );
          var borrowToken : tokenInfo := getTokenInfo(
            liquidateParams.borrowToken,
            s
          );

          verifyTokenUpdated(borrowToken);

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
          const maxClose : nat = borrowerBorrowAmountFloat * s.closeFactorFloat
            / accuracy;

          if liqAmountFloat <= maxClose
          then skip
          else failwith("yToken/too-much-repay");

          borrowerBorrowAmountFloat := abs(
            borrowerBorrowAmountFloat - liqAmountFloat
          );
          borrowerLastBorrowIndex := borrowToken.borrowIndex;
          borrowToken.totalBorrowsFloat := abs(
            borrowToken.totalBorrowsFloat - liqAmountFloat
          );
          (* TODO: increase the liquid amount of tokens *)

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

          verifyTokenUpdated(collateralToken);

          (* seizeAmount = actualRepayAmount * liquidationIncentive
            * priceBorrowed / priceCollateral
            seizeTokens = seizeAmount / exchangeRate
          *)
          (* TODO: immprove accurancy by calculating the numerator and
          denominator instead of exchangeRateFloat; ie.
          numerator = liqAmountFloat * s.liqIncentiveFloat
            * borrowToken.lastPrice * collateralToken.totalSupplyFloat
          denominator = abs(
            collateralToken.totalLiquidFloat + collateralToken.totalBorrowsFloat
            - collateralToken.totalReservesFloat
          ) * accuracy * collateralToken.lastPrice *)
          const exchangeRateFloat : nat = abs(
            collateralToken.totalLiquidFloat + collateralToken.totalBorrowsFloat
            - collateralToken.totalReservesFloat
          ) * accuracy / collateralToken.totalSupplyFloat;
          const seizeTokensFloat : nat = liqAmountFloat * s.liqIncentiveFloat
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

          if tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

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

          if tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

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
          (* TODO: remove unneccessary condition about outstandingBorrowInCU = 0n;
          it makes no sense as if outstandingBorrowInCU == 0 it is always <=
          maxBorrowInCU *)
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

    (* TODO: rename to simpleInterestFactorFloat, interestAccumulatedFloat*)
    const simpleInterestFactor : nat = borrowRate * blockDelta;
    const interestAccumulated : nat = simpleInterestFactor *
      token.totalBorrowsFloat / accuracy;

    token.totalBorrowsFloat := interestAccumulated + token.totalBorrowsFloat;
    // one mult operation with float require accuracy division
    token.totalReservesFloat := interestAccumulated * token.reserveFactorFloat /
      accuracy + token.totalReservesFloat;
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
        UpdReserveFactor(token.reserveFactorFloat),
        0mutez,
        getReserveFactorContract(token.interstRateModel)
      )
    ];
  } with (operations, s)
