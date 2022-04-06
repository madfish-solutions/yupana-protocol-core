const oraclePricePrecision: nat = 1_000_000n; // 10^6

[@inline] function getNormalizerContract(
  const oracleAddress   : address)
                        : contract(getType) is
  unwrap(
    (Tezos.get_entrypoint_opt("%get", oracleAddress)
                        : option(contract(getType))),
    Errors.Proxy.wrongOContract
  )

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
    const price : nat = oraclePrice * precision / (decimals * oraclePricePrecision);

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