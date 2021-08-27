// test contract for InterestRate entrypoint

type storage            is record [
  utilRate              : nat;
  borrowRate            : nat;
  supplyRate            : nat;
  interestAddress       : address;
]

type return is list (operation) * storage

[@inline] const noOperations : list (operation) = nil;

type mainParams         is record [
  tokenId               : nat;
  amount                : nat;
]

type setCoeffParams     is [@layout:comb] record [
  kickRate              : nat;
  baseRate              : nat;
  multiplier            : nat;
  jumpMultiplier        : nat;
]

type rateParams         is [@layout:comb] record [
  tokenId               : nat;
  borrows               : nat;
  cash                  : nat;
  reserves              : nat;
  contract              : contract(mainParams);
]

type interestParams     is [@layout:comb] record [
  tokenId               : nat;
  borrows               : nat;
  cash                  : nat;
  reserves              : nat;
]

type rateAction         is
  | UpdateRateAdmin of address
  | UpdateRateYToken of address
  | SetCoefficients of setCoeffParams
  | GetBorrowRate of rateParams
  | GetUtilizationRate of rateParams
  | GetSupplyRate of rateParams
  | EnsuredSupplyRate of rateParams
  | UpdReserveFactor of nat

type entryAction is
  | SetInterestRate of address
  | SendUtil of interestParams
  | UpdateUtilRate of mainParams
  | SendBorrow of interestParams
  | UpdateBorrowRate of mainParams
  | SendSupply of interestParams
  | UpdateSupplyRate of mainParams
  | GetReserveFactor of nat


[@inline] function getRateContract(
  const addr            : address)
                        : contract(rateAction) is
  case (
    Tezos.get_entrypoint_opt("%rateUse", addr)
                        : option(contract(rateAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("getInterest/cant-get-rate-contract") : contract(rateAction)
    )
  end;

[@inline] function getUpdateUtilRateContract(
  const interestAddress : address)
                        : contract(mainParams) is
  case(
    Tezos.get_entrypoint_opt("%updateUtilRate", interestAddress)
                        : option(contract(mainParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("getInterest/cant-get-utilRate") : contract(mainParams)
    )
  end;

[@inline] function getUpdateBorrowRateContract(
  const interestAddress : address)
                        : contract(mainParams) is
  case(
    Tezos.get_entrypoint_opt("%updateBorrowRate", interestAddress)
                        : option(contract(mainParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("getInterest/cant-get-borrowRate") : contract(mainParams)
    )
  end;

[@inline] function getUpdateSupplyRateContract(
  const interestAddress : address)
                        : contract(mainParams) is
  case(
    Tezos.get_entrypoint_opt("%updateSupplyRate", interestAddress)
                        : option(contract(mainParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("getInterest/cant-get-SupplyRate") : contract(mainParams)
    )
  end;

[@inline] function geteRateContract(
  const rateAddress     : address)
                        : contract(rateAction) is
  case(
    Tezos.get_entrypoint_opt("%rateUse", rateAddress)
                        : option(contract(rateAction))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("yToken/cant-get-interestRate-contract") : contract(rateAction)
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
          contract = getUpdateUtilRateContract(Tezos.self_address);
        ]),
        0mutez,
        getRateContract(s.interestAddress)
      );
    ]
  } with (operations , s)

function updateUtilRate(
  const p               : mainParams;
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
          contract = getUpdateBorrowRateContract(Tezos.self_address)
        ]),
        0mutez,
        getRateContract(s.interestAddress)
      );
    ]
  } with (operations , s)

function updateBorrowRate(
  const p               : mainParams;
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
          contract = getUpdateSupplyRateContract(Tezos.self_address)
        ]),
        0mutez,
        getRateContract(s.interestAddress)
      );
    ]
  } with (operations , s)

function updateSupplyRate(
  const p               : mainParams;
  var s                 : storage)
                        : return is
  block {
    s.supplyRate := p.amount;
  } with (noOperations, s)


function getReserveFactor(
  const _tokenId        : nat;
  var s                 : storage)
                        : return is
  block {
    if Tezos.sender =/= s.interestAddress
    then failwith("yToken/permition-error");
    else skip;
    const reserveFactor : nat = 250n;

    const operations : list(operation) = list [
      Tezos.transaction(
        UpdReserveFactor(reserveFactor),
        0mutez,
        geteRateContract(s.interestAddress)
      )
    ];
  } with (operations, s)

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
    | GetReserveFactor(params) -> getReserveFactor(params , s)
  end;
