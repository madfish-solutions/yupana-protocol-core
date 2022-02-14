function mustBeAdmin(
  const s               : yStorage)
                        : unit is
  if Tezos.sender =/= s.admin
  then failwith("yToken/not-admin")
  else unit

function setAdmin(
  const p               : useAction;
  var s                 : yStorage)
                        : return is
  block {
    case p of
      SetAdmin(newAdmin) -> {
        mustBeAdmin(s);
        s.admin := newAdmin;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function withdrawReserve(
  const p               : useAction;
  var s                 : yStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      WithdrawReserve(params) -> {
        mustBeAdmin(s);
        var token : tokenType := getToken(params.tokenId, s.tokens);
        const amountF = params.amount * precision;

        token.totalReservesF :=
          case is_nat(token.totalReservesF - amountF) of
            | None -> (failwith("underflow/totalReservesF") : nat)
            | Some(value) -> value
          end;

        s.tokens[params.tokenId] := token;

        operations := transfer_token(
          Tezos.self_address,
          Tezos.sender,
          params.amount,
          token.mainToken
        );
      }
    | _                 -> skip
    end
  } with (operations, s)

[@inline] function checkTypeInfo(
  const typeInfo        : big_map(assetType, tokenId);
  const assertType      : assetType)
                        : unit is
  case typeInfo[assertType] of
    None -> unit
  | Some(_v) -> failwith("yToken/token-has-already-been-added")
  end

function addMarket(
  const params          : newMarketParams;
  var s                 : fullStorage)
                        : fullReturn is
  block {
    mustBeAdmin(s.storage);
    var token : tokenType := getToken(s.storage.lastTokenId, s.storage.tokens);
    const lastTokenId : nat = s.storage.lastTokenId;

    checkTypeInfo(s.storage.assets, params.asset);

    (* TODO: fail if token exist - not fixed yet *)
    token.interestRateModel := params.interestRateModel;
    token.mainToken := params.asset;
    token.collateralFactorF := params.collateralFactorF;
    token.reserveFactorF := params.reserveFactorF;
    token.maxBorrowRate := params.maxBorrowRate;
    token.threshold := params.threshold;

    s.storage.assets[params.asset] := lastTokenId;
    s.token_metadata[lastTokenId] := record [
      token_id = lastTokenId;
      token_info = params.token_metadata;
    ];
    s.storage.tokens[lastTokenId] := token;
    s.storage.lastTokenId := lastTokenId + 1n;
  } with (noOperations, s)

function updateMetadata(
  const params          : updateMetadataParams;
  var s                 : fullStorage)
                        : fullReturn is
  block {
    const tokenId : nat = params.tokenId;

    mustBeAdmin(s.storage);
    s.token_metadata[tokenId] := record [
      token_id = tokenId;
      token_info = params.token_metadata;
    ];
  } with (noOperations, s)

function setTokenFactors(
  const p               : useAction;
  var s                 : yStorage)
                        : return is
  block {
    case p of
      SetTokenFactors(params) -> {
        mustBeAdmin(s);
        var token : tokenType := getToken(params.tokenId, s.tokens);

        if token.interestUpdateTime < Tezos.now
        then failwith("yToken/need-update")
        else skip;

        token.collateralFactorF := params.collateralFactorF;
        token.reserveFactorF := params.reserveFactorF;
        token.interestRateModel := params.interestRateModel;
        token.maxBorrowRate := params.maxBorrowRate;
        token.threshold := params.threshold;
        s.tokens[params.tokenId] := token;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function setGlobalFactors(
  const p               : useAction;
  var s                 : yStorage)
                        : return is
  block {
    case p of
      SetGlobalFactors(params) -> {
        mustBeAdmin(s);
        s.closeFactorF := params.closeFactorF;
        s.liqIncentiveF := params.liqIncentiveF;
        s.priceFeedProxy := params.priceFeedProxy;
        s.maxMarkets := params.maxMarkets;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function setBorrowPause(
  const p               : useAction;
  var s                 : yStorage)
                        : return is
  block {
    case p of
      SetBorrowPause(borrowPauseParams) -> {
        mustBeAdmin(s);
        var token : tokenType := getToken(borrowPauseParams.tokenId, s.tokens);
        token.borrowPause := borrowPauseParams.condition;
        s.tokens[borrowPauseParams.tokenId] := token;
      }
    | _                 -> skip
    end
  } with (noOperations, s)
