#include "../partial/MainTypes.ligo"
#include "../partial/yToken/LendingMethods.ligo"

function middleToken(
  const p               : tokenAction;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    const idx : nat = case p of
      | ITransfer(_transferParams) -> 0n
      | IUpdateOperators(_updateOperatorParams) -> 1n
      | IBalanceOf(_balanceParams) -> 2n
      | IGetTotalSupply(_totalSupplyParams) -> 3n
    end;
    const res : return = case s.tokenLambdas[idx] of
      Some(f) -> f(p, s.storage)
      | None -> (
        failwith("yToken/middle-token-function-not-set") : return
      )
    end;
    s.storage := res.1;
  } with (res.0, s)


[@inline] function funcsMiddleUse(
  const p               : useAction;
  const this            : address;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    const idx : nat = case p of
      | Mint(_mainParams) -> 0n
      | Redeem(_mainParams) -> 1n
      | Borrow(_mainParams) -> 2n
      | EnsuredBorrow(_mainParams) -> 3n
      | Repay(_mainParams) -> 4n
      | Liquidate(_liquidateParams) -> 5n
      | EnsuredLiquidate(_liquidateParams) -> 6n
      | SetAdmin(_addr) -> 7n
      | WithdrawReserve(_mainParams) -> 9n
      | AddMarket(_newMarketParams) -> 10n
      | SetTokenFactors(_setTokenParams) -> 11n
      | SetGlobalFactors(_setGlobalParams) -> 12n
      | EnterMarket(_tokenId) -> 13n
      | ExitMarket(_tokenId) -> 14n
      | EnsuredExitMarket(_tokenId) -> 15n
      | UpdatePrice(_mainParams) -> 16n
      | GetReserveFactor(_tokenId) -> 17n
    end;
    const res : return = case s.useLambdas[idx] of
      Some(f) -> f(p, s.storage, this)
      | None -> (
        failwith("yToken/middle-function-not-set-in-middleUse") : return
      )
    end;
    s.storage := res.1;
  } with (res.0, s)

[@inline] function middleUse(
  const p               : useAction;
  const this            : address;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    var operations : list(operation) := list[];
    const shouldUpdate : bool = case p of
      | Mint(_mainParams) -> true
      | Redeem(_mainParams) -> true
      | Borrow(_mainParams) -> true
      | EnsuredBorrow(_mainParams) -> false
      | Repay(_mainParams) -> true
      | Liquidate(_liquidateParams) -> true
      | EnsuredLiquidate(_liquidateParams) -> false
      | SetAdmin(_addr) -> false
      | WithdrawReserve(_mainParams) -> false
      | AddMarket(_newMarketParams) -> false
      | SetTokenFactors(_setTokenParams) -> false
      | SetGlobalFactors(_setGlobalParams) -> false
      | EnterMarket(_tokenId) -> false
      | ExitMarket(_tokenId) -> true
      | EnsuredExitMarket(_tokenId) -> false
      | UpdatePrice(_mainParams) -> false
      | GetReserveFactor(_tokenId) -> false
    end;

    if shouldUpdate
    then block {
      operations := list[
        Tezos.transaction(
          UpdateInterest(0n, this), // ????
          0mutez,
          getUpdateInterestEntrypoint(this)
        );
        Tezos.transaction(
          FuncsUse(p, this),
          0mutez,
          getFuncsMiddleUseEntrypoint(this)
        );
      ];
    }
    else block {
      operations := list[
        Tezos.transaction(
          FuncsUse(p, this),
          0mutez,
          getFuncsMiddleUseEntrypoint(this)
        )
      ];
    }
  } with (operations, s)

function main(
  const p               : entryAction;
  const s               : fullTokenStorage)
                        : fullReturn is
  block {
     const this : address = Tezos.self_address;
  } with case p of
      | Transfer(params)          -> middleToken(ITransfer(params), s)
      | UpdateOperators(params)   -> middleToken(IUpdateOperators(params), s)
      | BalanceOf(params)         -> middleToken(IBalanceOf(params), s)
      | GetTotalSupply(params)    -> middleToken(IGetTotalSupply(params), s)
      | UpdateInterest(params)   -> updateInterest(params, this, s)
      | EnsuredUpdateInterest(params) -> ensuredUpdateInterest(params, s)
      | FuncsUse(params)          -> funcsMiddleUse(params, this, s)
      | Use(params)               -> middleUse(params, this, s)
    end
