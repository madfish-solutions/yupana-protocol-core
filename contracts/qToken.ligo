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
const accuracy : nat = 100000000n;

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
    const hundredPercent : nat = 10000000000000000n;
    const apr : nat = 250000000000000n; // 2.5% (0.025)
    const utilizationBase : nat = 2000000000000000n; // 20% (0.2)
    const secondsPerYear : nat = 31536000n;
    const reserveFactor : nat = 10000000000000n;// 0.1% (0.001)
    const utilizationBasePerSec : nat = 63419584n; // utilizationBase / secondsPerYear; 0.0000000063419584
    const debtRatePerSec : nat = 7927448n; // apr / secondsPerYear; 0.0000000007927448

    const utilizationRate_ : nat = s.totalBorrows / abs(s.totalLiquid + s.totalBorrows - s.totalReserves);
    const borrowRatePerSec_ : nat = (utilizationRate_ * (utilizationBasePerSec * accuracy)  + (debtRatePerSec * accuracy)) / hundredPercent;
    const simpleInterestFactor_ : nat = borrowRatePerSec_ * abs(Tezos.now - s.lastUpdateTime) * accuracy;
    const interestAccumulated_ : nat = simpleInterestFactor_ * s.totalBorrows;

    s.totalBorrows := interestAccumulated_ + s.totalBorrows;
    s.totalReserves := interestAccumulated_ * reserveFactor / hundredPercent + s.totalReserves;
    s.borrowIndex := simpleInterestFactor_ * s.borrowIndex + s.borrowIndex;
  } with (s)

// TODO FOR ALL add total liqudity
// TODO FOR ALL add operations
function mint(const user : address; const amt : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    s := updateInterest(s);

    const exchangeRate : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) / s.totalSupply;
    const mintTokens : nat = amt * accuracy / exchangeRate;

    s.accountTokens[user] := getTokens(user, s) + mintTokens;
    s.totalSupply := s.totalSupply + mintTokens;
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
    var exchangeRate : nat := abs(s.totalLiquid + s.totalBorrows - s.totalReserves) / s.totalSupply;

    if exchangeRate = 0n then
      failwith("NotEnoughTokensToSendToUser")
    else skip;

    if amt = 0n then
      amt := accountTokens / accuracy;
    else skip;
    burnTokens := amt * accuracy / exchangeRate;

    
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

function repay(const user : address; const amt : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    s := updateInterest(s);

    var accountBorrows : borrows := getBorrows(user, s);
    accountBorrows.amount := accountBorrows.amount * s.borrowIndex / accountBorrows.lastBorrowIndex;
    accountBorrows.amount := abs(accountBorrows.amount - amt * accuracy);
    accountBorrows.lastBorrowIndex := s.borrowIndex;

    s.accountBorrows[user] := accountBorrows;
    s.totalBorrows := abs(s.totalBorrows - amt * accuracy);
  } with (list [Tezos.transaction(Transfer(Tezos.sender, (Tezos.self_address, amt)), 
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


    const liquidationIncentive : nat = 105000000n;// 105% (1.05) from accuracy
    const exchangeRate : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) / s.totalSupply;
    const seizeTokens : nat = amt * liquidationIncentive / accuracy / exchangeRate;

    debtorBorrows.amount := debtorBorrows.amount * s.borrowIndex / debtorBorrows.lastBorrowIndex;
    debtorBorrows.amount := abs(debtorBorrows.amount - seizeTokens);
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