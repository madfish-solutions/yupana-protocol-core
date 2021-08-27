// test contract for Proxy entrypoint

type storage is record [
  lastDate        : timestamp;
  lastPrice       : nat;
  returnAddress   : address;
]

type oracleParam is (string * (timestamp * nat))

type pairParam          is record [
  tokenId               : nat;
  pairName              : string;
]

type proxyAction        is
  | UpdateAdmin of address
  | UpdateOracle of address
  | UpdatePair of pairParam
  | GetPrice of nat
  | ReceivePrice of oracleParam

[@inline] const noOperations : list (operation) = nil;

type return is list (operation) * storage

type contrParam is (string * (timestamp * nat))
type updParams is (string * contract(contrParam))

type updParamsOracleParams is record [
  price : nat;
  time  : timestamp;
]

type entryAction is
  | Get of updParams
  | UpdParamsOracle of updParamsOracleParams
  | UpdReturnAddressOracle of address


[@inline] function getProxyContract(
  const priceFeedProxy  : address)
                        : contract(proxyAction) is
  case(
    Tezos.get_entrypoint_opt("%proxyUse", priceFeedProxy)
                        : option(contract(proxyAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("oracle/cant-get-contract-proxy") : contract(proxyAction)
    )
  end;

function get(
  const upd             : updParams;
  const s               : storage)
                        : return is
  block {
    var requestedAsset : string := upd.0;

    var lastUpdateTime : timestamp := s.lastDate;
    var lastPrice : nat := s.lastPrice;

    var callbackParam : contrParam := (
      requestedAsset, (lastUpdateTime, lastPrice)
    );

    var operations := list [
      Tezos.transaction(callbackParam,
        0mutez,
        upd.1
      );
    ]
  } with (operations, s)

function updParamsOracle(
  const price           : nat;
  const time            : timestamp;
  var s                 : storage)
                        : return is
  block {
    s.lastPrice := price;
    s.lastDate := time;

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
    | UpdParamsOracle(params) -> updParamsOracle(params.price, params.time, s)
    | UpdReturnAddressOracle(params) -> updReturnAddressOracle(params, s)
  end;
