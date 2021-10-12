// test contract for Proxy entrypoint

type updateParam is record [
  name                  : string;
  price                 : nat;
  time                  : timestamp;
]

type priceParam is [@layout:comb] record [
  price : nat;
  time : timestamp;
]

type storage is record [
  tokenInfo       : big_map(string, priceParam);
  returnAddress   : address;
]

[@inline] const noOperations : list (operation) = nil;

type return is list (operation) * storage

type contrParam is (string * (timestamp * nat))
type updParams is (string * contract(contrParam))

type entryAction is
  | Get of updParams
  | UpdParamsOracle of updateParam
  | UpdReturnAddressOracle of address

function getInfo(
  const name            : string;
  const s               : storage)
                        : priceParam is
  case s.tokenInfo[name] of
    None -> record [
      price = 0n;
      time  = (0 : timestamp)
    ]
  | Some(v) -> v
  end

function get(
  const upd             : updParams;
  const s               : storage)
                        : return is
  block {
    var requestedAsset : string := upd.0;

    const info : priceParam = getInfo(upd.0, s);
    var lastUpdateTime : timestamp := info.time;
    var tokenInfo : nat := info.price;

    var callbackParam : contrParam := (
      requestedAsset, (lastUpdateTime, tokenInfo)
    );

    var operations := list [
      Tezos.transaction(callbackParam,
        0mutez,
        upd.1
      );
    ]
  } with (operations, s)

function updParamsOracle(
  const param           : updateParam;
  var s                 : storage)
                        : return is
  block {
    var info : priceParam := getInfo(param.name, s);

    info.price := param.price;
    info.time := param.time;
    s.tokenInfo[param.name] := info;

  } with (noOperations, s)

function updReturnAddressOracle(
  const newAddress      : address;
  var s                 : storage)
                        : return is
  block {
    s.returnAddress := newAddress;
  } with (noOperations, s)


function main(
  const action          : entryAction;
  var s                 : storage)
                        : return is
  block {
    skip
  } with case action of
    | Get(params) -> get(params, s)
    | UpdParamsOracle(params) -> updParamsOracle(params, s)
    | UpdReturnAddressOracle(params) -> updReturnAddressOracle(params, s)
  end;
