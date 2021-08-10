#include "../partial/yToken/MainTypes.ligo"
#include "../partial/yToken/FA2Methods.ligo"
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

[@inline] function middleUse(
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
      end;
    const res : return = case s.useLambdas[idx] of
      Some(f) -> f(p, s.storage, this)
      | None -> (
        failwith("yToken/middle-function-not-set-in-middleUse") : return
      )
    end;
    s.storage := res.1;
  } with (res.0, s)

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
      | Use(params)               -> middleUse(params, this, s)
    end
