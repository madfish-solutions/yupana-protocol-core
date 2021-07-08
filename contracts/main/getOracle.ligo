// test contract for oracle entrypoint
#include "../partials/MainTypes.ligo"

type storage is record [
  lastDate        : timestamp;
  lastPrice       : nat;
  returnAddress   : address;
]

[@inline] const noOperations : list (operation) = nil;

type return is list (operation) * storage

type updParamsOracleParams is record [
  price : nat;
  time  : timestamp;
]

type entryAction is
  | Get of updParams
  | UpdParamsOracle of updParamsOracleParams
  | UpdReturnAddressOracle of address

[@inline] function getUseController (const tokenAddress : address) : contract(useControllerParam) is
  case (Tezos.get_entrypoint_opt("%useController", tokenAddress) : option(contract(useControllerParam))) of
    Some(contr) -> contr
    | None -> (failwith("CantGetContractController") : contract(useControllerParam))
  end;

function get (const upd : updParams; const s : storage) : return is
  block {
    var requestedAsset : string := upd.0;

    var lastUpdateTime : timestamp := s.lastDate;
    var lastPrice : nat := s.lastPrice;

    var callbackParam : contrParam := (requestedAsset, (lastUpdateTime, lastPrice));

    var operations := list [
      Tezos.transaction(
        UpdatePrice(callbackParam),
        0mutez,
        getUseController(s.returnAddress)
      );
    ]

  } with (operations, s)

function updParamsOracle (const price : nat; const time : timestamp; var s : storage) : return is
  block {
    s.lastPrice := price;
    s.lastDate := time;

  } with (noOperations, s)

function updReturnAddressOracle (const newAddress : address; var s : storage) : return is
  block {
    s.returnAddress := newAddress;
  } with (noOperations, s)


function main (const action : entryAction; var s : storage) : return is
  block {
    skip
  } with case action of
    | Get(params) -> get(params, s)
    | UpdParamsOracle(params) -> updParamsOracle(params.price, params.time, s)
    | UpdReturnAddressOracle(params) -> updReturnAddressOracle(params, s)
  end;
