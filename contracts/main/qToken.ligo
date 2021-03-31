#include "../partials/MainTypes.ligo"
#include "../partials/qTokenMethods.ligo"

[@inline] function middleToken (const p : tokenAction; const s : fullTokenStorage) :  fullReturn is
block {
    const idx : nat = case p of
      | ITransfer(transferParams) -> 0n
      | IApprove(approveParams) -> 1n
      | IGetBalance(balanceParams) -> 2n
      | IGetAllowance(allowanceParams) -> 3n
      | IGetTotalSupply(totalSupplyParams) -> 4n
    end;
  const res : return = case s.tokenLambdas[idx] of
    Some(f) -> f(p, s.storage)
    | None -> (failwith("qTokenMiddleTokenFunctionNotSet") : return)
  end;
  s.storage := res.1;
} with (res.0, s)

[@inline] function middleUse (const p : useAction; const this : address; const s : fullTokenStorage) : fullReturn is
block {
    const idx : nat = case p of
      | SetAdmin(addr) -> 0n
      | SetOwner(addr) -> 1n
      | Mint(mintParams) -> 2n
      | Redeem(redeemParams) -> 3n
      | Borrow(borrowParams) -> 4n
      | Repay(repayParams) -> 5n
      | Liquidate(liquidateParams) -> 6n
      | Seize(seizeParams) -> 7n
      | UpdateControllerState(addr) -> 8n
    end;
  const res : return = case s.useLambdas[idx] of
    Some(f) -> f(p, s.storage, this)
    | None -> (failwith("qTokenMiddleTokenFunctionNotSetInMiddleUse") : return)
  end;
  s.storage := res.1;
} with (res.0, s)

function main (const p : entryAction; const s : fullTokenStorage) : fullReturn is
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
