[@inline] function mustBeAdmin(
  const s               : proxyStorage)
                        : unit is
  block {
    if Tezos.sender =/= s.admin
    then failwith("proxy/not-admin")
    else skip;
  } with (unit)

[@inline] function mustBeYtoken(
  const s               : proxyStorage)
                        : unit is
  block {
    if Tezos.sender =/= s.yToken
    then failwith("proxy/not-yToken")
    else skip;
  } with (unit)

[@inline] function mustBeOracle(
  const s               : proxyStorage)
                        : unit is
  block {
    if Tezos.sender =/= s.oracle
    then failwith("proxy/not-oracle")
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
      failwith("proxy/cant-get-oracle") : contract(getType)
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
      failwith("proxy/cant-get-receivePrice") : contract(oracleParam)
    )
  end;

[@inline] function getYtokenContract(
  const s               : proxyStorage)
                        : contract(mainParams) is
  case (
    Tezos.get_entrypoint_opt("%returnPrice", s.yToken)
                        : option(contract(mainParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("proxy/cant-get-yToken") : contract(mainParams)
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
  var s                 : proxyStorage)
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

function updateOracle(
  const p               : proxyAction;
  var s                 : proxyStorage)
                        : proxyReturn is
  block {
    case p of
      UpdateOracle(addr) -> {
        mustBeAdmin(s);
        s.oracle := addr;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function updateYToken(
  const p               : proxyAction;
  var s                 : proxyStorage)
                        : proxyReturn is
  block {
    case p of
      UpdateYToken(addr) -> {
        mustBeAdmin(s);
        s.yToken := addr;
      }
    | _                 -> skip
    end
  } with (noOperations, s)


function receivePrice(
  const p               : proxyAction;
  const s               : proxyStorage)
                        : proxyReturn is
  block {
    var operations : list(operation) := list[];
      case p of
        ReceivePrice(oracleParam) -> {
          mustBeOracle(s);

          const tokenId : nat = checkPairId(oracleParam.0, s);

          operations := list[
            Tezos.transaction(
              record [
                tokenId = tokenId;
                amount = oracleParam.1.1;
              ],
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
  const s               : proxyStorage)
                        : proxyReturn is
  block {
    var operations : list(operation) := list[];
      case p of
        GetPrice(tokenId) -> {
          mustBeYtoken(s);

          const strName : string = checkPairName(tokenId, s);
          const param : contract(oracleParam) = getReceivePriceEntrypoint(Tezos.self_address);

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
  var s                 : proxyStorage)
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
