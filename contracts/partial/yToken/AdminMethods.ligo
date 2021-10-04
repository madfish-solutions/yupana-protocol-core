function mustBeAdmin(
  const s               : tokenStorage)
                        : unit is
  if Tezos.sender =/= s.admin
  then failwith("yToken/not-admin")
  else unit

function setAdmin(
  const newAdmin        : address;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    mustBeAdmin(s.storage);
    s.storage.admin := newAdmin;
  } with (noOperations, s)

function withdrawReserve(
  const params          : yAssetParams;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    mustBeAdmin(s.storage);
    var token : tokenInfo := getTokenInfo(params.tokenId, s.storage);
    const amountFloat = params.amount * accuracy;

    if amountFloat > token.totalReservesFloat
    then failwith("yToken/withdraw-is-too-big");
    else skip;

    token.totalReservesFloat := abs(
      token.totalReservesFloat -amountFloat
    );
    s.storage.tokenInfo[params.tokenId] := token;

    var operations : list(operation) := list [
        case token.faType of
        | FA12 -> Tezos.transaction(
            TransferOutside(record [
              from_ = Tezos.self_address;
              to_ = Tezos.sender;
              value = params.amount
            ]),
            0mutez,
            getTokenContract(token.mainToken)
          )
        | FA2(assetId) -> Tezos.transaction(
            IterateTransferOutside(record [
              from_ = Tezos.self_address;
              txs = list[
                record[
                  tokenId = assetId;
                  to_ = Tezos.sender;
                  amount = params.amount / accuracy;
                ]
              ]
            ]),
            0mutez,
            getIterTranserContract(token.mainToken)
          )
        end
    ];
  } with (operations, s)

function addMarket(
  const params          : newMarketParams;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    mustBeAdmin(s.storage);
    var token : tokenInfo := getTokenInfo(s.storage.lastTokenId, s.storage);

    (* TODO: fail if token exist - not fixed yet *)
    token.interstRateModel := params.interstRateModel;
    token.mainToken := params.assetAddress;
    token.collateralFactorFloat := params.collateralFactorFloat;
    token.reserveFactorFloat := params.reserveFactorFloat;
    token.maxBorrowRate := params.maxBorrowRate;
    token.faType := params.faType;

    const lastTokenId : nat = s.storage.lastTokenId;
    // s.storage.typesInfo[(params.assetAddress, params.faType)] := lastTokenId;

    s.storage.tokenMetadata[lastTokenId] := record [
      tokenId = lastTokenId;
      tokenInfo = params.tokenMetadata;
    ];
    s.storage.tokenInfo[lastTokenId] := token;
    s.storage.lastTokenId := lastTokenId + 1n;
  } with (noOperations, s)

// function updateMetadata(
//   const params          : updateMetadataParams;
//    var s                : fullTokenStorage)
//                         : fullReturn is
//   block {
//     mustBeAdmin(s.storage);
//     s.storage.tokenMetadata[params.tokenId] := record [
//       tokenId = params.tokenId;
//       tokenInfo = params.tokenMetadata;
//     ];
//   } with (noOperations, s)

function setTokenFactors(
  const params          : setTokenParams;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    mustBeAdmin(s.storage);
    var token : tokenInfo := getTokenInfo(params.tokenId, s.storage);

    if token.lastUpdateTime < Tezos.now
    then failwith("yToken/need-update")
    else skip;

    token.collateralFactorFloat := params.collateralFactorFloat;
    token.reserveFactorFloat := params.reserveFactorFloat;
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
    s.storage.closeFactorFloat := params.closeFactorFloat;
    s.storage.liqIncentiveFloat := params.liqIncentiveFloat;
    s.storage.priceFeedProxy := params.priceFeedProxy;
    s.storage.maxMarkets := params.maxMarkets;
  } with (noOperations, s)
