function mustBeAdmin(
  const s               : tokenStorage)
                        : unit is
  if Tezos.sender =/= s.admin
  then failwith("NotAdmin")
  else unit

function mustBeOwner(
  const s               : tokenStorage)
                        : unit is
  if Tezos.sender =/= s.owner
  then failwith("NotOwner")
  else unit

function setAdmin(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
      case p of
        SetAdmin(addr) -> {
          mustBeOwner(s);
          s.admin := addr;
        }
      | _                         -> skip
      end
  } with (noOperations, s)

function setOwner(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
      case p of
        SetOwner(addr) -> {
          mustBeOwner(s);
          s.owner := addr;
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

          token.totalReserves := abs(token.totalReserves - mainParams.amount * accurancy);
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

function setCollaterallFactor(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
    case p of
      SetCollaterallFactor(mainParams) -> {
        mustBeAdmin(s);
        var token : tokenInfo := getTokenInfo(mainParams.tokenId, s);
        token.collateralFactor := mainParams.amount;
        s.tokenInfo[mainParams.tokenId] := token;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function setReserveFactor(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
    case p of
      SetReserveFactor(mainParams) -> {
        mustBeAdmin(s);
        var token : tokenInfo := getTokenInfo(mainParams.tokenId, s);
        token.reserveFactor := mainParams.amount;
        s.tokenInfo[mainParams.tokenId] := token;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function setModel(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
    case p of
      SetModel(setModelParams) -> {
        mustBeAdmin(s);
        var token : tokenInfo := getTokenInfo(setModelParams.tokenId, s);
        token.interstRateModel := setModelParams.modelAddress;
        s.tokenInfo[setModelParams.tokenId] := token;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function setCloseFactor(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
    case p of
      SetCloseFactor(amt) -> {
        mustBeAdmin(s);
        s.closeFactor := amt;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function setLiquidationIncentive(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
    case p of
      SetLiquidationIncentive(amt) -> {
        mustBeAdmin(s);
        s.liqIncentive := amt;
      }
      | _               -> skip
      end
  } with (noOperations, s)

function setProxyAddress(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
    case p of
      SetProxyAddress(addr) -> {
        mustBeAdmin(s);
        s.priceFeedProxy := addr;
      }
    | _                 -> skip
    end
  } with (noOperations, s)
