function verifyUpdatedRates(
  const setOfTokens     : set(tokenId);
  var s                 : tokenStorage)
                        : tokenStorage is
  block {
    function updInterest(
      var s             : tokenStorage;
      const tokenId     : tokenId)
                        : tokenStorage is
      block {
        var token : tokenInfo := getTokenInfo(tokenId, s);
        if token.lastUpdateTime > ((Tezos.now + 60) : timestamp)
        then failwith("yToken/need-update-interestRate")
        else skip;
      } with s
  } with Set.fold(updInterest, setOfTokens, s)

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
  const params          : mainParams;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    mustBeAdmin(s.storage);
    var token : tokenInfo := getTokenInfo(params.tokenId, s.storage);

    token.totalReserves := abs(
      token.totalReserves - params.amount * accuracy
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
    var token : tokenInfo := getTokenInfo(s.storage.lastTokenId, s.storage);

    token.interstRateModel := params.interstRateModel;
    token.mainToken := params.assetAddress;
    token.collateralFactor := params.collateralFactor;
    token.reserveFactor := params.reserveFactor;
    token.maxBorrowRate := params.maxBorrowRate;
    token.faType := params.faType;

    s.storage.tokenMetadata[s.storage.lastTokenId] := record [
      tokenId = s.storage.lastTokenId;
      tokenInfo = params.tokenMetadata;
    ];
    s.storage.tokenInfo[s.storage.lastTokenId] := token;
    s.storage.lastTokenId := s.storage.lastTokenId + 1n;
  } with (noOperations, s)

function setTokenFactors(
  const params          : setTokenParams;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    mustBeAdmin(s.storage);
    s.storage := verifyUpdatedRates(set [params.tokenId], s.storage);

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
    s.storage.maxMarkets := params.maxMarkets;
  } with (noOperations, s)
