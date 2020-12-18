type borrows is
  record [
    amount           :nat;
    lastBorrowIndex  :nat;
  ]

type storage is
  record [
    owner           :address;
    admin           :address;
    token           :address;
    lastUpdateTime  :timestamp;
    totalBorrows    :nat;
    totalLiquid     :nat;
    totalSupply     :nat;
    totalReserves   :nat;
    borrowIndex     :nat;
    accountBorrows  :big_map(address, borrows);
    accountTokens   :big_map(address, nat);
  ]
//all numbers in storage are real numbers
const accuracy : nat = 1000000000000000000n; //1e+18

type return is list (operation) * storage
[@inline] const noOperations : list (operation) = nil;

type transfer_type is Transfer of michelson_pair(address, "from", michelson_pair(address, "to", nat, "value"), "")

type mintParams is michelson_pair(address, "user", nat, "amount")
type redeemParams is michelson_pair(address, "user", nat, "amount")
type borrowParams is michelson_pair(address, "user", nat, "amount")
type repayParams is michelson_pair(address, "user", nat, "amount")
type liquidateParams is michelson_pair(address, "liquidator", michelson_pair(address, "borrower", nat, "amount"), "")

type entryAction is
  | SetAdmin of address
  | SetOwner of address
  | Mint of mintParams
  | Redeem of redeemParams
  | Borrow of borrowParams
  | Repay of repayParams
  | Liquidate of liquidateParams

function getBorrows(const addr : address; const s : storage) : borrows is
  block {
    var b : borrows :=
      record [
        amount          = 0n;
        lastBorrowIndex = 0n;
      ];
    case s.accountBorrows[addr] of
      None -> skip
    | Some(value) -> b := value
    end;
  } with b

function getTokens(const addr : address; const s : storage) : nat is
  case s.accountTokens[addr] of
    Some (value) -> value
  | None -> 0n
  end;

function getTokenContract(const token_address : address) : contract(transfer_type) is 
  case (Tezos.get_entrypoint_opt("%transfer", token_address) : option(contract(transfer_type))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetContractToken") : contract(transfer_type))
  end;

[@inline] function mustBeOwner(const s : storage) : unit is
  block {
    if Tezos.sender =/= s.owner then
      failwith("NotOwner")
    else skip;
  } with (unit)

[@inline] function mustBeAdmin(const s : storage) : unit is
  block {
    if Tezos.sender =/= s.admin then
      failwith("NotAdmin")
    else skip;
  } with (unit)

function setAdmin(const newAdmin : address; var s : storage) : return is
  block {
    mustBeOwner(s);
    s.admin := newAdmin;
  } with (noOperations, s)

function setOwner(const newOwner : address; var s : storage) : return is
  block {
    mustBeOwner(s);
    s.owner := newOwner;
  } with (noOperations, s)

function updateInterest(var s : storage) : storage is
  block {
    const apr : nat = 25000000000000000n; // 2.5% (0.025) from accuracy
    const utilizationBase : nat = 200000000000000000n; // 20% (0.2)
    const secondsPerYear : nat = 31536000n;
    const reserveFactorFloat : nat = 1000000000000000n;// 0.1% (0.001)
    const utilizationBasePerSecFloat : nat = 6341958397n; // utilizationBase / secondsPerYear; 0.000000006341958397
    const debtRatePerSecFloat : nat = 792744800n; // apr / secondsPerYear; 0.000000000792744800

    const utilizationRateFloat : nat = s.totalBorrows * accuracy / abs(s.totalLiquid + s.totalBorrows - s.totalReserves); // one div operation with float require accuracy mult
    const borrowRatePerSecFloat : nat = utilizationRateFloat * utilizationBasePerSecFloat / accuracy + debtRatePerSecFloat; // one mult operation with float require accuracy division
    const simpleInterestFactorFloat : nat = borrowRatePerSecFloat * abs(Tezos.now - s.lastUpdateTime);
    const interestAccumulatedFloat : nat = simpleInterestFactorFloat * s.totalBorrows / accuracy; // one mult operation with float require accuracy division

    s.totalBorrows := interestAccumulatedFloat + s.totalBorrows;
    s.totalReserves := interestAccumulatedFloat * reserveFactorFloat / accuracy + s.totalReserves; // one mult operation with float require accuracy division
    s.borrowIndex := simpleInterestFactorFloat * s.borrowIndex / accuracy + s.borrowIndex; // one mult operation with float require accuracy division
  } with (s)

function mint(const user : address; const amt : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    s := updateInterest(s);

    const exchangeRateFloat : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) * accuracy / s.totalSupply;
    const mintTokensFloat : nat = amt * accuracy * accuracy / exchangeRateFloat;

    s.accountTokens[user] := getTokens(user, s) + mintTokensFloat;
    s.totalSupply := s.totalSupply + mintTokensFloat;
    s.totalLiquid := s.totalLiquid + amt * accuracy;
  } with (list [Tezos.transaction(Transfer(user, (Tezos.self_address, amt)), 
         0mutez, 
         getTokenContract(s.token))], s)

function redeem(const user : address; var amt : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    s := updateInterest(s);

    var burnTokens : nat := 0n;
    const accountTokens : nat = getTokens(user, s);
    const exchangeRateFloat : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) * accuracy / s.totalSupply;

    if exchangeRateFloat = 0n then
      failwith("NotEnoughTokensToSendToUser")
    else skip;

    if amt = 0n then
      amt := accountTokens / accuracy;
    else skip;
    if s.totalLiquid < amt * accuracy then
      failwith("NotEnoughLiquid")
    else skip;

    burnTokens := amt * accuracy * accuracy / exchangeRateFloat;

    if accountTokens < burnTokens then
      failwith("NotEnoughTokensToBurn")
    else skip;

    
    s.accountTokens[user] := abs(accountTokens - burnTokens);
    s.totalSupply := abs(s.totalSupply - burnTokens);
    s.totalLiquid := abs(s.totalLiquid - amt * accuracy);
  } with (list [Tezos.transaction(Transfer(Tezos.self_address, (user, amt)), 
         0mutez, 
         getTokenContract(s.token))], s)

function borrow(const user : address; var amt : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    //make amt as real number
    amt := amt * accuracy;
    if s.totalLiquid < amt then
      failwith("AmountTooBig")
    else skip;
    s := updateInterest(s);

    var accountBorrows : borrows := getBorrows(user, s);
    accountBorrows.amount := accountBorrows.amount + amt;
    accountBorrows.lastBorrowIndex := s.borrowIndex;

    s.accountBorrows[user] := accountBorrows;
    s.totalBorrows := s.totalBorrows + amt;
  } with (list [Tezos.transaction(Transfer(Tezos.self_address, (Tezos.sender, amt / accuracy)), 
         0mutez, 
         getTokenContract(s.token))], s)

function repay(const user : address; var amt : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    s := updateInterest(s);
    amt := amt * accuracy;

    var accountBorrows : borrows := getBorrows(user, s);
    accountBorrows.amount := accountBorrows.amount * s.borrowIndex / accountBorrows.lastBorrowIndex;
    if accountBorrows.amount < amt then
      failwith("AmountShouldBeLessOrEqual")
    else skip;
    accountBorrows.amount := abs(accountBorrows.amount - amt);
    accountBorrows.lastBorrowIndex := s.borrowIndex;

    s.accountBorrows[user] := accountBorrows;
    s.totalBorrows := abs(s.totalBorrows - amt);
  } with (list [Tezos.transaction(Transfer(Tezos.sender, (Tezos.self_address, amt / accuracy)), 
         0mutez, 
         getTokenContract(s.token))], s)

function liquidate(const liquidator : address; const borrower : address; var amt : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    s := updateInterest(s);
    if liquidator = borrower then
      failwith("BorrowerCannotBeLiquidator")
    else skip;

    var debtorBorrows : borrows := getBorrows(borrower, s);
    if amt = 0n then
      amt := debtorBorrows.amount
    else
      amt := amt * accuracy;


    const liquidationIncentive : nat = 1050000000000000000n;// 105% (1.05) from accuracy
    const exchangeRateFloat : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) * accuracy / s.totalSupply;
    const seizeTokens : nat = amt * liquidationIncentive / exchangeRateFloat;

    debtorBorrows.amount := debtorBorrows.amount * s.borrowIndex / debtorBorrows.lastBorrowIndex;
    if debtorBorrows.amount < amt then
      failwith("AmountShouldBeLessOrEqual")
    else skip;
    debtorBorrows.amount := abs(debtorBorrows.amount - amt);
    debtorBorrows.lastBorrowIndex := s.borrowIndex;

    s.accountBorrows[borrower] := debtorBorrows;
    s.accountTokens[liquidator] := getTokens(liquidator, s) + seizeTokens;
  } with (list [Tezos.transaction(Transfer(Tezos.sender, (Tezos.self_address, amt / accuracy)), 
         0mutez,
         getTokenContract(s.token))], s)

function main(const action : entryAction; var s : storage) : return is
  block {
    skip
  } with case action of
    | SetAdmin(params) -> setAdmin(params, s)
    | SetOwner(params) -> setOwner(params, s)
    | Mint(params) -> mint(params.0, params.1, s)
    | Redeem(params) -> redeem(params.0, params.1, s)
    | Borrow(params) -> borrow(params.0, params.1, s)
    | Repay(params) -> repay(params.0, params.1, s)
    | Liquidate(params) -> liquidate(params.0, params.1.0, params.1.1, s)
  end;
