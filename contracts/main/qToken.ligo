#include "../partial/MainTypes.ligo"
#include "../partial/qTokenMethods.ligo"

[@inline] function middleToken(
  const p               : tokenAction;
  var s                 : fullTokenStorage)
                        :  fullReturn is
block {
    const idx : nat = case p of
      | ITransfer(_transferParams) -> 0n
      | IApprove(_approveParams) -> 1n
      | IGetBalance(_balanceParams) -> 2n
      | IGetAllowance(_allowanceParams) -> 3n
      | IGetTotalSupply(_totalSupplyParams) -> 4n
    end;
  const res : return = case s.tokenLambdas[idx] of
    Some(f) -> f(p, s.storage)
    | None -> (
      failwith("qTokenMiddleTokenFunctionNotSet") : return
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
      | SetAdmin(_addr) -> 0n
      | SetOwner(_addr) -> 1n
      | Mint(_mintParams) -> 2n
      | Redeem(_redeemParams) -> 3n
      | Borrow(_borrowParams) -> 4n
      | Repay(_repayParams) -> 5n
      | Liquidate(_liquidateParams) -> 6n
      | Seize(_seizeParams) -> 7n
      | UpdateControllerState(_addr) -> 8n
    end;
  const res : return = case s.useLambdas[idx] of
    Some(f) -> f(p, s.storage, this)
    | None -> (
      failwith("qTokenMiddleTokenFunctionNotSetInMiddleUse") : return
    )
  end;
  s.storage := res.1;
} with (res.0, s)

function main(
  const p               : entryAction;
  const s               : fullTokenStorage)
                        : fullReturn is
  block {
     const this: address = Tezos.self_address;
  } with case p of
      | Transfer(params)              -> middleToken(ITransfer(params), s)
      | Approve(params)               -> middleToken(IApprove(params), s)
      | GetBalance(params)            -> middleToken(IGetBalance(params), s)
      | GetAllowance(params)          -> middleToken(IGetAllowance(params), s)
      | GetTotalSupply(params)        -> middleToken(IGetTotalSupply(params), s)
      | Use(params)                   -> middleUse(params, this, s)
    end
