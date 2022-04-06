const oraclePricePrecision: nat = 1_000_000n; // 10^6

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
        const oraclePrice : nat = unwrap(
          (Tezos.call_view("get_price", strName, s.oracle) : option(nat)),
          Errors.Proxy.wrongOContract
        );
        const decimals : nat = getDecimal(strName, s.tokensDecimals);
        const price : nat = oraclePrice * precision / (decimals * oraclePricePrecision);
        const tokenId : nat = checkPairId(strName, s.pairId);
        const priceResponse: yAssetParams = record [
            tokenId = tokenId;
            amount = price;
        ];
        var op : operation := Tezos.transaction(
          priceResponse,
          0mutez,
          getYTokenPriceCallbackMethod(s.yToken)
        );
      } with op # operations;

      const operations = Set.fold(
        oneTokenUpd,
        tokenSet,
        (nil : list(operation))
      );
  } with (operations, s)