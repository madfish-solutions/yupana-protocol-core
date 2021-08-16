function mustBeAdmin(
  const s               : tokenStorage)
                        : unit is
  if Tezos.sender =/= s.admin
  then failwith("not-admin")
  else unit

function setAdmin(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
      case p of
        SetAdmin(addr) -> {
          mustBeAdmin(s);
          s.admin := addr;
        }
      | _                         -> skip
      end
  } with (noOperations, s)

function withdrawReserve(
  const p               : useAction;
  var s                 : tokenStorage;
  const this            : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        WithdrawReserve(mainParams) -> {
          mustBeAdmin(s);
          var token : tokenInfo := getTokenInfo(mainParams.tokenId, s);

          token.totalReserves := abs(
            token.totalReserves - mainParams.amount * accuracy
          );
          s.tokenInfo[mainParams.tokenId] := token;

          operations := list [
            Tezos.transaction(
              TransferOutside(record [
                from_ = this;
                to_ = Tezos.sender;
                value = mainParams.amount / accuracy
              ]),
              0mutez,
              getTokenContract(token.mainToken)
            )
          ]
        }
      | _               -> skip
      end
  } with (operations, s)

function addMarket(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
    case p of
      AddMarket(newMarketParams) -> {
        var token : tokenInfo := getTokenInfo(s.lastTokenId, s);

        token.interstRateModel := newMarketParams.interstRateModel;
        token.mainToken := newMarketParams.assetAddress;
        token.collateralFactor := newMarketParams.collateralFactor;
        token.reserveFactor := newMarketParams.reserveFactor;
        token.maxBorrowRate := newMarketParams.maxBorrowRate;

        s.tokenMetadata[s.lastTokenId] := record [
          tokenId = s.lastTokenId;
          tokenInfo = newMarketParams.tokenMetadata;
        ];
        s.tokenInfo[s.lastTokenId] := token;
        s.lastTokenId := s.lastTokenId + 1n;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function setTokenFactors(
  const params          : setTokenParams;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    mustBeAdmin(s.storage);
    var token : tokenInfo := getTokenInfo(params.tokenId, s.storage);
    token.collateralFactor := params.collateralFactor;
    token.reserveFactor := params.reserveFactor;
    token.interstRateModel := params.interstRateModel;
    token.maxBorrowRate := params.maxBorrowRate;
    s.storage.tokenInfo[params.tokenId] := token;
  } with (noOperations, s)

function setGlobalFactors(
  const params          : setGlobalParams;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    mustBeAdmin(s.storage);
    s.storage.closeFactor := params.closeFactor;
    s.storage.liqIncentive := params.liqIncentive;
    s.storage.priceFeedProxy := params.priceFeedProxy;
  } with (noOperations, s)
