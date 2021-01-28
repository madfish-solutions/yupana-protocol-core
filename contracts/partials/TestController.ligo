#include "../partials/ITestController.ligo"

function setFactory(const newFecAddress: address; const s : storage) : return is
  block {
    if (Tezos.sender = s.admin) then
      s.factory := newFecAddress;
    else skip;
  } with (noOperations, s)


[@inline] function mustNotContainsQTokens(const qToken : address; const s : storage) : unit is
  block {
    if (s.qTokens contains qToken) then
      failwith("Contains")
    else skip;
  } with (unit)

function register(const token : address; const qToken : address; var s : storage) : return is
  block {
    if Tezos.sender =/= s.factory then
      failwith("NotFactory")
    else skip;

    mustNotContainsQTokens(qToken, s);

    s.qTokens := Set.add(qToken, s.qTokens);
    s.pairs[token] := qToken;
  } with (noOperations, s)


// function main(const action : entryAction; var s : storage) : return is
//     block {
//         skip
//     } with case action of
//         | SetFactory(params) -> setFactory(params, s)
//         | Register(params) -> register(params.token, params.qToken, s)
//     end;
