function mustBeAdmin(
  const admin           : address)
                        : unit is
  require(Tezos.sender = admin, Errors.Proxy.notAdmin)

function checkTimestamp(
  const oracleTimestamp : timestamp;
  const limit           : int)
                        : unit is
  require(oracleTimestamp >= Tezos.now - limit, Errors.Proxy.timestampLimit);


[@inline] function mustBeOracle(
  const oracle          : address)
                        : unit is
  require(Tezos.sender = oracle, Errors.Proxy.notOracle)

[@inline] function getNormalizerContract(
  const oracleAddress   : address)
                        : contract(getType) is
  unwrap(
    (Tezos.get_entrypoint_opt("%get", oracleAddress)
                        : option(contract(getType))),
    Errors.Proxy.wrongOContract
  )

[@inline] function getYTokenPriceCallbackMethod(
  const yToken          : address)
                        : contract(yAssetParams) is
  unwrap(
    (Tezos.get_entrypoint_opt("%priceCallback", yToken)
                        : option(contract(yAssetParams))),
    Errors.Proxy.wrongYContract
  )

[@inline] function getDecimal(
  const pairName        : string;
  const tokensDecimals  : big_map(string, nat))
                        : nat is
  unwrap(tokensDecimals[pairName], Errors.Proxy.PairCheck.decimals)

[@inline] function checkPairName(
  const tokenId         : tokenId;
  const pairName        : big_map(tokenId, string))
                        : string is
  unwrap(pairName[tokenId], Errors.Proxy.PairCheck.pairString)

[@inline] function checkPairId(
  const pairName        : string;
  const pairId          : big_map(string, tokenId))
                        : nat is
  unwrap(pairId[pairName], Errors.Proxy.PairCheck.tokenId)

function setProxyAdmin(
  const addr            : address;
  var s                 : proxyStorage)
                        : proxyReturn is
  block {
    mustBeAdmin(s.admin);
    s.admin := addr;
  } with (noOperations, s)

function setTimeLimit(
  const limit           : nat;
  var s                 : proxyStorage)
                        : proxyReturn is
  block {
    mustBeAdmin(s.admin);
    s.timestampLimit := int(limit);
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
  var s                 : proxyStorage)
                        : proxyReturn is
  block {
    mustBeOracle(s.oracle);
    checkTimestamp(param.1.0, s.timestampLimit);
    const pairName : string = param.0;
    const oraclePrice = param.1.1;
    const decimals : nat = getDecimal(pairName, s.tokensDecimals);
    const price : nat = oraclePrice * precision / decimals;

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
