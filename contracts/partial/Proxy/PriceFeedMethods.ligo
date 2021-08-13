[@inline] function mustBeAdmin(
  const s               : proxyStorage)
                        : unit is
  block {
    if Tezos.sender =/= s.admin
    then failwith("not-admin")
    else skip;
  } with (unit)

[@inline] function mustBeYtoken(
  const s               : proxyStorage)
                        : unit is
  block {
    if Tezos.sender =/= s.yToken
    then failwith("not-yToken")
    else skip;
  } with (unit)

[@inline] function mustBeOracle(
  const s               : proxyStorage)
                        : unit is
  block {
    if Tezos.sender =/= s.oracle
    then failwith("not-oracle")
    else skip;
  } with (unit)

[@inline] function getNormalizerContract(
  const oracleAddress   : address)
                        : contract(getType) is
  case (
    Tezos.get_entrypoint_opt("%get", oracleAddress)
                        : option(contract(getType))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("cant-get-oracle-entrypoint") : contract(getType)
    )
  end;

[@inline] function getReceivePriceEntrypoint(
  const contractAddress : address)
                        : contract(oracleParam) is
  case (
    Tezos.get_entrypoint_opt("%receivePrice", contractAddress)
                        : option(contract(oracleParam))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("cant-get-receivePrice-entrypoint") : contract(oracleParam)
    )
  end;

[@inline] function getYtokenContract(
  const s               : proxyStorage)
                        : contract(useParam) is
  case (
    Tezos.get_entrypoint_opt("%updatePrice", s.yToken)
                        : option(contract(useParam))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("cant-get-yToken-entrypoint") : contract(useParam)
    )
  end;

[@inline] function checkPairName(
  const tokenId         : tokenId;
  const s               : proxyStorage)
                        : string is
  case s.pairName[tokenId] of
    | Some(v) -> v
    | None -> (failwith("checkPairName/string-not-defined") : string)
  end;

[@inline] function checkPairId(
  const pairName        : string;
  const s               : proxyStorage)
                        : nat is
  case s.pairId[pairName] of
    | Some(v) -> v
    | None -> (failwith("checkPairId/tokenId-not-defined") : nat)
  end;

function updateAdmin(
  const p               : proxyAction;
  var s                 : proxyStorage;
  const _this           : address)
                        : proxyReturn is
  block {
    case p of
      UpdateAdmin(addr) -> {
        mustBeAdmin(s);
        s.admin := addr;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function receivePrice(
  const p               : proxyAction;
  var s                 : proxyStorage;
  const _this           : address)
                        : proxyReturn is
  block {
    var operations : list(operation) := list[];
      case p of
        ReceivePrice(oracleParam) -> {
          mustBeOracle(s);

          const tokenId : nat = checkPairId(oracleParam.0, s);
          const param : mainParams = record [
            tokenId = tokenId;
            amount = oracleParam.1.1;
          ];

          operations := list[
            Tezos.transaction(
              UpdatePrice(param),
              0mutez,
              getYtokenContract(s)
            )
          ];
        }
      | _               -> skip
      end
  } with (operations, s)

function getPrice(
  const p               : proxyAction;
  var s                 : proxyStorage;
  const this            : address)
                        : proxyReturn is
  block {
    var operations : list(operation) := list[];
      case p of
        GetPrice(tokenId) -> {
          mustBeYtoken(s);

          const strName : string = checkPairName(tokenId, s);
          var param : contract(oracleParam) := getReceivePriceEntrypoint(this);

          operations := list[
            Tezos.transaction(
              Get(strName, param),
              0mutez,
              getNormalizerContract(s.oracle)
            )
          ];
        }
      | _               -> skip
      end
  } with (operations, s)

function updatePair(
  const p               : proxyAction;
  var s                 : proxyStorage;
  const _this           : address)
                        : proxyReturn is
  block {
      case p of
        UpdatePair(pairParam) -> {
          mustBeAdmin(s);
          s.pairName[pairParam.tokenId] := pairParam.pairName;
          s.pairId[pairParam.pairName] := pairParam.tokenId;
        }
      | _               -> skip
      end
  } with (noOperations, s)
