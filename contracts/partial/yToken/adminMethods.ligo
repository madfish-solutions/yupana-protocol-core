function mustBeAdmin(
  const s               : tokenStorage)
                        : unit is
  if Tezos.sender =/= s.admin
  then failwith("yToken/not-admin")
  else unit

function setAdmin(
  const p               : useAction;
  var s                 : tokenStorage)
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
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      WithdrawReserve(params) -> {
        mustBeAdmin(s);
        var token : tokenInfo := getTokenInfo(params.tokenId, s.tokenInfo);
        const amountF = params.amount * precision;

        if amountF > token.totalReservesF
        then failwith("yToken/withdraw-is-too-big");
        else skip;

        token.totalReservesF :=
          case is_nat(token.totalReservesF - amountF) of
            | None -> (failwith("underflow/totalReservesF") : nat)
            | Some(value) -> value
          end;

        s.tokenInfo[params.tokenId] := token;

        operations := transfer_token(
          Tezos.self_address,
          Tezos.sender,
          params.amount / precision,
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
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    case p of
      AddMarket(params) -> {
        mustBeAdmin(s);
        var token : tokenInfo := getTokenInfo(s.lastTokenId, s.tokenInfo);
        const lastTokenId : nat = s.lastTokenId;

        checkTypeInfo(s.typesInfo, params.assetAddress);

        (* TODO: fail if token exist - not fixed yet *)
        token.interestRateModel := params.interestRateModel;
        token.mainToken := params.assetAddress;
        token.collateralFactorF := params.collateralFactorF;
        token.reserveFactorF := params.reserveFactorF;
        token.maxBorrowRate := params.maxBorrowRate;

        s.typesInfo[params.assetAddress] := lastTokenId;
        s.tokenMetadata[lastTokenId] := record [
          token_id = lastTokenId;
          tokenInfo = params.tokenMetadata;
        ];
        s.tokenInfo[lastTokenId] := token;
        s.lastTokenId := lastTokenId + 1n;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function updateMetadata(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    case p of
      UpdateMetadata(params) -> {
        const tokenId : nat = params.tokenId;

        mustBeAdmin(s);
        s.tokenMetadata[tokenId] := record [
          token_id = tokenId;
          tokenInfo = params.tokenMetadata;
        ];
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function setTokenFactors(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    case p of
      SetTokenFactors(params) -> {
        mustBeAdmin(s);
        var token : tokenInfo := getTokenInfo(params.tokenId, s.tokenInfo);

        if token.interestUpdateTime < Tezos.now
        then failwith("yToken/need-update")
        else skip;

        token.collateralFactorF := params.collateralFactorF;
        token.reserveFactorF := params.reserveFactorF;
        token.interestRateModel := params.interestRateModel;
        token.maxBorrowRate := params.maxBorrowRate;
        s.tokenInfo[params.tokenId] := token;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function setGlobalFactors(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    case p of
      SetGlobalFactors(params) -> {
        mustBeAdmin(s);
        s.closeFactorF := params.closeFactorF;
        s.liqIncentiveF := params.liqIncentiveF;
        s.priceFeedProxy := params.priceFeedProxy;
        s.maxMarkets := params.maxMarkets;
        s.threshold := params.threshold;
      }
    | _                 -> skip
    end
  } with (noOperations, s)

function setBorrowPause(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    case p of
      SetBorrowPause(borrowPauseParams) -> {
        mustBeAdmin(s);
        var token : tokenInfo := getTokenInfo(borrowPauseParams.tokenId, s.tokenInfo);
        token.borrowPause := borrowPauseParams.condition;
        s.tokenInfo[borrowPauseParams.tokenId] := token;
      }
    | _                 -> skip
    end
  } with (noOperations, s)
