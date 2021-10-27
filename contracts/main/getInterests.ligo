// test contract for InterestRate entrypoint

type storage            is record [
  utilRate              : nat;
  borrowRate            : nat;
  supplyRate            : nat;
  interestAddress       : address;
]

type return is list (operation) * storage

[@inline] const noOperations : list (operation) = nil;

type yAssetParams         is record [
  tokenId               : nat;
  amount                : nat;
]

type setCoeffParams     is [@layout:comb] record [
  kickRateFloat         : nat;
  baseRateFloat         : nat;
  multiplierFloat       : nat;
  jumpMultiplierFloat   : nat;
]

type rateParams         is [@layout:comb] record [
  tokenId               : nat;
  borrows               : nat;
  cash                  : nat;
  reserves              : nat;
  precision              : nat;
  contract              : contract(yAssetParams);
]

type interestParams     is [@layout:comb] record [
  tokenId               : nat;
  borrows               : nat;
  cash                  : nat;
  reserves              : nat;
  precision              : nat;
]

type entryRateAction         is
  | UpdateAdmin of address
  | UpdateYToken of address
  | SetCoefficients of setCoeffParams
  | GetBorrowRate of rateParams
  | GetUtilizationRate of rateParams
  | GetSupplyRate of rateParams
  | EnsuredSupplyRate of rateParams
  | UpdReserveFactor of nat

type entryAction is
  | SetInterestRate of address
  | SendUtil of interestParams
  | UpdateUtilRate of yAssetParams
  | SendBorrow of interestParams
  | UpdateBorrowRate of yAssetParams
  | SendSupply of interestParams
  | UpdateSupplyRate of yAssetParams
  // | GetReserveFactor of nat


[@inline] function getUtilRateContract(
  const addr            : address)
                        : contract(entryRateAction) is
  case (
    Tezos.get_entrypoint_opt("%getUtilizationRate", addr)
                        : option(contract(entryRateAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("getInterest/cant-get-rate-contract") : contract(entryRateAction)
    )
  end;

[@inline] function getBorrowRateContract(
  const addr            : address)
                        : contract(entryRateAction) is
  case (
    Tezos.get_entrypoint_opt("%getBorrowRate", addr)
                        : option(contract(entryRateAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("getInterest/cant-get-rate-contract") : contract(entryRateAction)
    )
  end;

[@inline] function getSupplyRateContract(
  const addr            : address)
                        : contract(entryRateAction) is
  case (
    Tezos.get_entrypoint_opt("%getSupplyRate", addr)
                        : option(contract(entryRateAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("getInterest/cant-get-rate-contract") : contract(entryRateAction)
    )
  end;

[@inline] function getUpdateUtilRateContract(
  const interestAddress : address)
                        : contract(yAssetParams) is
  case(
    Tezos.get_entrypoint_opt("%updateUtilRate", interestAddress)
                        : option(contract(yAssetParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("getInterest/cant-get-utilRate") : contract(yAssetParams)
    )
  end;

[@inline] function getUpdateBorrowRateContract(
  const interestAddress : address)
                        : contract(yAssetParams) is
  case(
    Tezos.get_entrypoint_opt("%updateBorrowRate", interestAddress)
                        : option(contract(yAssetParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("getInterest/cant-get-borrowRate") : contract(yAssetParams)
    )
  end;

[@inline] function getUpdateSupplyRateContract(
  const interestAddress : address)
                        : contract(yAssetParams) is
  case(
    Tezos.get_entrypoint_opt("%updateSupplyRate", interestAddress)
                        : option(contract(yAssetParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("getInterest/cant-get-SupplyRate") : contract(yAssetParams)
    )
  end;

[@inline] function getUpdRateContract(
  const rateAddress     : address)
                        : contract(entryRateAction) is
  case(
    Tezos.get_entrypoint_opt("%updReserveFactor", rateAddress)
                        : option(contract(entryRateAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("getInterests/cant-get-interestRate-contract") : contract(entryRateAction)
    )
  end;

function setInterestRate(
  const addr          : address;
  var s               : storage)
                      : return is
  block {
    s.interestAddress := addr
  } with (noOperations, s)

function sendUtil(
  const p               : interestParams;
  const s               : storage)
                        : return is
  block {

    var operations := list [
      Tezos.transaction(
        GetUtilizationRate(record[
          tokenId = p.tokenId;
          borrows = p.borrows;
          cash = p.cash;
          reserves = p.reserves;
          precision = p.precision;
          contract = getUpdateUtilRateContract(Tezos.self_address);
        ]),
        0mutez,
        getUtilRateContract(s.interestAddress)
      );
    ]
  } with (operations , s)

function updateUtilRate(
  const p               : yAssetParams;
  var s                 : storage)
                        : return is
  block {
    s.utilRate := p.amount;
  } with (noOperations, s)

function sendBorrow(
  const p               : interestParams;
  const s               : storage)
                        : return is
  block {

    var operations := list [
      Tezos.transaction(
        GetBorrowRate(record[
          tokenId = p.tokenId;
          borrows = p.borrows;
          cash = p.cash;
          reserves = p.reserves;
          precision = p.precision;
          contract = getUpdateBorrowRateContract(Tezos.self_address)
        ]),
        0mutez,
        getBorrowRateContract(s.interestAddress)
      );
    ]
  } with (operations , s)

function updateBorrowRate(
  const p               : yAssetParams;
  var s                 : storage)
                        : return is
  block {
    s.borrowRate := p.amount;
  } with (noOperations, s)

function sendSupply(
  const p               : interestParams;
  const s               : storage)
                        : return is
  block {

    var operations := list [
      Tezos.transaction(
        GetSupplyRate(record[
          tokenId = p.tokenId;
          borrows = p.borrows;
          cash = p.cash;
          reserves = p.reserves;
          precision = p.precision;
          contract = getUpdateSupplyRateContract(Tezos.self_address)
        ]),
        0mutez,
        getSupplyRateContract(s.interestAddress)
      );
    ]
  } with (operations , s)

function updateSupplyRate(
  const p               : yAssetParams;
  var s                 : storage)
                        : return is
  block {
    s.supplyRate := p.amount;
  } with (noOperations, s)

function main(
  const action          : entryAction;
  var s                 : storage)
                        : return is
  case action of
    | SetInterestRate(params) -> setInterestRate(params, s)
    | SendUtil(params) -> sendUtil(params, s)
    | UpdateUtilRate(params) -> updateUtilRate(params, s)
    | SendBorrow(params) -> sendBorrow(params, s)
    | UpdateBorrowRate(params) -> updateBorrowRate(params, s)
    | SendSupply(params) -> sendSupply(params, s)
    | UpdateSupplyRate(params) -> updateSupplyRate(params, s)
  end;
