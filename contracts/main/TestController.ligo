type storage is
  record [
    factory           :address;
    admin             :address;
    qTokens           :set(address);
    pairs             :big_map(address, address);
  ]

type registerParams is record [
    token        :address;
    qToken       :address;
]

type fectoryParams is address;

[@inline] const noOperations : list (operation) = nil;

type entryAction is 
    Register of registerParams
    | SetFectory of fectoryParams

function setFectory(const newFecAddress: address; const s : storage) : address is
  block {
    if (Tezos.sender == s.admin) then
        s.factory = newFecAddress;
  }


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


function main(const action : entryAction; var s : storage) : return is
    block {
        skip
    } with case action of
        | Register(params) -> register(params.token, params.qToken, s)
        | SetFectory(params) -> setFectory(params.newFecAddress, s)
