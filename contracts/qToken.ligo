type storage is
  record [
    owner           :address;
    admin           :address;
    lastUpdateTime  :timestamp;
    totalBorrows    :nat;
    totalLiquid     :nat;
    totalSupply     :nat;
    totalReserves   :nat;
    borrowIndex     :nat;
    accountBorrows  :big_map(address, nat);
    accountTokens   :big_map(address, nat);
  ]


type return is list (operation) * storage
const noOperations : list (operation) = nil;

// type entryAction is
//   | 

function mustGetAdmin(const s : storage) : address is
  block {
  //   const admin : address =
  // ("tz1KqTpEZ7Yob7QbPE4Hy4Wo8fHG8LhKxZSx" : address);
    var admin : address := ("" : address);
    case s.admin of
      None -> failwith("AdminNotSet")
    | Some(a) -> admin := a
    end;
  } with admin

function setAdmin(var s : storage) : return is
  block {
    if Tezos.sender =/= mustGetAdmin(s) then
      failwith("NotAdmin")
    else skip;
  } with (noOperations, s)

// function setOwner() is {

// }



// function main(const action : entryAction; var s : storage) : return is
//   block {
//     skip
//   } with case action of
//     | Transfer(params) -> transfer(params.0, params.1.0, params.1.1, s)
//   end;