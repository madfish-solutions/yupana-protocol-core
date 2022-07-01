function mustBeAdmin(
  const s               : yStorage)
                        : unit is
  require(Tezos.sender = s.admin, Errors.YToken.notAdmin)

function setAdmin(
  const p               : useAction;
  var s                 : yStorage)
                        : return is
  block {
    case p of
      SetAdmin(newAdmin) -> {
        mustBeAdmin(s);
        s.admin_candidate := Some(newAdmin);
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function approveAdmin(
  const p               : useAction;
  var s                 : yStorage)
                        : return is
  block {
    case p of
      ApproveAdmin(_) -> {
        const admin_candidate : address = unwrap(s.admin_candidate, Errors.YToken.noCandidate);
        require(Tezos.sender = admin_candidate or Tezos.sender = s.admin, Errors.YToken.notAdminOrCandidate);
        s.admin := Tezos.sender;
        s.admin_candidate := (None : option(address));
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
        verifyInterestUpdated(token);
        const amountF = params.amount * precision;

        token.totalReservesF := get_nat_or_fail(token.totalReservesF - amountF, Errors.YToken.lowReserves);
        token.totalLiquidF := get_nat_or_fail(token.totalLiquidF - amountF, Errors.YToken.lowLiquidity);

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

[@inline] function checkDuplicateAsset(
  const typeInfo        : big_map(assetType, tokenId);
  const asset           : assetType)
                        : unit is
  require_none(typeInfo[asset], Errors.YToken.tokenAlreadyAdded)

function addMarket(
  const params          : newMarketParams;
  var s                 : fullStorage)
                        : fullReturn is
  block {
    mustBeAdmin(s.storage);
    var token : tokenType := getToken(s.storage.lastTokenId, s.storage.tokens);
    const lastTokenId : nat = s.storage.lastTokenId;

    checkDuplicateAsset(s.storage.assets, params.asset);

    (* TODO: fail if token exist - not fixed yet *)
    token.interestRateModel := params.interestRateModel;
    token.mainToken := params.asset;
    token.collateralFactorF := params.collateralFactorF;
    token.reserveFactorF := params.reserveFactorF;
    token.maxBorrowRate := params.maxBorrowRate;
    token.threshold := params.threshold;
    token.liquidReserveRateF := params.liquidReserveRateF;

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
        verifyInterestUpdated(token);

        token.collateralFactorF := params.collateralFactorF;
        token.reserveFactorF := params.reserveFactorF;
        token.interestRateModel := params.interestRateModel;
        token.maxBorrowRate := params.maxBorrowRate;
        token.threshold := params.threshold;
        token.liquidReserveRateF := params.liquidReserveRateF;
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
      SetBorrowPause(pauseParams) -> {
        mustBeAdmin(s);
        var token : tokenType := getToken(pauseParams.tokenId, s.tokens);
        token.borrowPause := pauseParams.condition;
        s.tokens[pauseParams.tokenId] := token;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function setEnterMintPause(
  const p               : useAction;
  var s                 : yStorage)
                        : return is
  block {
    case p of
      SetEnterMintPause(pauseParams) -> {
        mustBeAdmin(s);
        var token : tokenType := getToken(pauseParams.tokenId, s.tokens);
        token.enterMintPause := pauseParams.condition;
        s.tokens[pauseParams.tokenId] := token;
      }
    | _                 -> skip
    end
  } with (noOperations, s)
