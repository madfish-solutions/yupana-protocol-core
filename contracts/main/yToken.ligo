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
      failwith("yTokenMiddleTokenFunctionNotSet") : return
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
      | Repay(_mainParams) -> 3n
      | Liquidate(_liquidateParams) -> 4n
      | SetAdmin(_addr) -> 5n
      | SetOwner(_addr) -> 6n
      | WithdrawReserve(_mainParams) -> 7n
      | AddMarket(_newMarketParams) -> 8n
      | SetCollaterallFactor(_mainParams) -> 9n
      | SetReserveFactor(_mainParams) -> 10n
      | SetModel(_setModelParams) -> 11n
      | SetCloseFactor(_amt) -> 12n
      | SetLiquidationIncentive(_amt) -> 13n
      | SetProxyAddress(_addr) -> 14n
      | EnterMarket(_tokenId) -> 15n
      | ExitMarket(_tokenId) -> 16n
    end;
  const res : return = case s.useLambdas[idx] of
    Some(f) -> f(p, s.storage, this)
    | None -> (
      failwith("yTokenMiddleTokenFunctionNotSetInMiddleUse") : return
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
