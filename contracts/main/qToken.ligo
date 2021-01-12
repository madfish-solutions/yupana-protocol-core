#include "../partials/qToken.ligo"

function checkFunc(const inx : nat; const s : fullStorage) : unit is
  case s.funcs[inx] of 
    Some (value) -> (failwith("AlreadySet") : unit)
  | None -> unit
  end;

function setFunc(const action : funcAction; var s : fullStorage) : fullReturn is
 block {
   case action of
   | SetAdminParams(params) -> s.funcs[1n] := params
   | SetOwnerParams(params) -> s.funcs[2n] := params
   | MintParams(params) -> s.funcs[3n] := params
   | RedeemParams(params) -> s.funcs[4n] := params
   | BorrowParams(params) -> s.funcs[5n] := params
   | RepayParams(params) -> s.funcs[6n] := params
   | LiquidateParams(params) -> s.funcs[7n] := params
   | SeizeParams(params) -> s.funcs[8n] := params
   | UpdateControllerStateParams(params) -> s.funcs[9n] := params
   end;
 } with (noOperations, s)

function executeFunc(const action : funcAction; var s : fullStorage) : fullReturn is
 block {
   failwith("test");
 } with (noOperations, s)

function main(const action : entryAction; var s : fullStorage) : fullReturn is
  block {
    skip
  } with case action of
    | SetFunc(params) -> setFunc(params, s)
    | ExecuteFunc(params) -> executeFunc(params, s)
  end;
