function mustBeAdmin(
  const admin           : address)
                        : unit is
  if Tezos.sender =/= admin
  then failwith("proxy/not-admin")
  else unit

[@inline] function mustBeOracle(
  const oracle          : address)
                        : unit is
  if Tezos.sender =/= oracle
  then failwith("proxy/not-oracle")
  else unit

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

[@inline] function getYTokenPriceCallbackMethod(
  const yToken          : address)
                        : contract(yAssetParams) is
  case (
    Tezos.get_entrypoint_opt("%priceCallback", yToken)
                        : option(contract(yAssetParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("proxy/cant-get-yToken") : contract(yAssetParams)
    )
  end;

[@inline] function getDecimal(
  const pairName        : string;
  const tokensDecimals  : big_map(string, nat))
                        : nat is
  case tokensDecimals[pairName] of
    | Some(v) -> v
    | None -> (failwith("checkPairName/decimals-not-defined") : nat)
  end;

[@inline] function checkPairName(
  const tokenId         : tokenId;
  const pairName        : big_map(tokenId, string))
                        : string is
  case pairName[tokenId] of
    | Some(v) -> v
    | None -> (failwith("checkPairName/string-not-defined") : string)
  end;

[@inline] function checkPairId(
  const pairName        : string;
  const pairId          : big_map(string, tokenId))
                        : nat is
  case pairId[pairName] of
    | Some(v) -> v
    | None -> (failwith("checkPairId/tokenId-not-defined") : nat)
  end;

function setProxyAdmin(
  const addr            : address;
  var s                 : proxyStorage)
                        : proxyReturn is
  block {
    mustBeAdmin(s.admin);
    s.admin := addr;
  } with (noOperations, s)

function updateOracle(
  const addr            : address;
  var s                 : proxyStorage)
                        : proxyReturn is
  block {
    mustBeAdmin(s.admin);
    s.oracle := addr;
  } with (noOperations, s)

function updateYToken(
  const addr            : address;
  var s                 : proxyStorage)
                        : proxyReturn is
  block {
    mustBeAdmin(s.admin);
    s.yToken := addr;
  } with (noOperations, s)


function receivePrice(
  const param           : oracleParam;
  var s               : proxyStorage)
                        : proxyReturn is
  block {
    mustBeOracle(s.oracle);
    const pairName : string = param.0;
    const decimals : nat = getDecimal(pairName, s.tokensDecimals);
    const price : nat = param.1.1 * precision / decimals;

    const tokenId : nat = checkPairId(pairName, s.pairId);
    var operations : list(operation) := list[
      Tezos.transaction(
        record [
          tokenId = tokenId;
          amount = price;
        ],
        0mutez,
        getYTokenPriceCallbackMethod(s.yToken)
      )
    ];
  } with (operations, s)

function getPrice(
  const tokenSet        : set(nat);
  const s               : proxyStorage)
                        : proxyReturn is
  block {
    function oneTokenUpd(
      const operations  : list(operation);
      const tokenId     : nat)
                        : list(operation) is
      block {
        const strName : string = checkPairName(tokenId, s.pairName);
        const param : contract(oracleParam) = Tezos.self("%receivePrice");

        const receivePriceOp = Tezos.transaction(
          Get(strName, param),
          0mutez,
          getNormalizerContract(s.oracle)
        );
      } with receivePriceOp # operations;

      const operations = Set.fold(
        oneTokenUpd,
        tokenSet,
        (nil : list(operation))
      );
  } with (operations, s)

function updatePair(
  const param           : pairParam;
  var s                 : proxyStorage)
                        : proxyReturn is
  block {
    mustBeAdmin(s.admin);
    s.pairName[param.tokenId] := param.pairName;
    s.pairId[param.pairName] := param.tokenId;
    s.tokensDecimals[param.pairName] := param.decimals;
  } with (noOperations, s)
