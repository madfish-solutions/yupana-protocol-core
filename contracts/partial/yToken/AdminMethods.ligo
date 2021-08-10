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
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
    case p of
      SetTokenFactors(setTokenParams) -> {
        mustBeAdmin(s);
        var token : tokenInfo := getTokenInfo(setTokenParams.tokenId, s);
        token.collateralFactor := setTokenParams.collateralFactor;
        token.reserveFactor := setTokenParams.reserveFactor;
        token.interstRateModel := setTokenParams.modelAddress;
        s.tokenInfo[setTokenParams.tokenId] := token;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function setGlobalFactors(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
    case p of
      SetGlobalFactors(setGlobalParams) -> {
        mustBeAdmin(s);
        s.closeFactor := setGlobalParams.closeFactor;
        s.liqIncentive := setGlobalParams.liqIncentive;
        s.priceFeedProxy := setGlobalParams.priceFeedProxy;
      }
    | _                 -> skip
    end
  } with (noOperations, s)
