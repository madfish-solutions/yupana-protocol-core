type borrows is
  record [
    amount           :nat;
    lastBorrowIndex  :nat;
  ]

type storage is
  record [
    owner           :address;
    admin           :address;
    lastUpdateTime  :timestamp;
    totalBorrows    :nat;
    totalLiquid     :nat;
    totalSupply     :nat;
    totalReserves   :nat;
    borrowIndex     :nat;
    accountBorrows  :big_map(address, borrows);
    accountTokens   :big_map(address, nat);
  ]


type return is list (operation) * storage
const noOperations : list (operation) = nil;

type entryAction is
  | SetAdmin of address
  | SetOwner of address
  | Mint of (address * nat)
  | Redeem of (address * nat)
  | Borrow of (address * nat)
  | Repay of (address * nat)
  | Liquidate of (address * address * nat * nat)

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

    const utilizationRate : nat = s.totalBorrows / abs(s.totalLiquid + s.totalBorrows - s.totalReserves);
    const borrowRatePerSec : nat = (utilizationRate * utilizationBasePerSec + debtRatePerSec) / hundredPercent;
    const simpleInterestFactor : nat = borrowRatePerSec * abs(Tezos.now - s.lastUpdateTime);
    const interestAccumulated : nat = simpleInterestFactor * s.totalBorrows;

    s.totalBorrows := interestAccumulated + s.totalBorrows;
    s.totalReserves := interestAccumulated * reserveFactor / hundredPercent + s.totalReserves;
    s.borrowIndex := simpleInterestFactor * s.borrowIndex + s.borrowIndex;
  } with (s)

// TODO FOR ALL add total liqudity
// TODO FOR ALL add operations
function mint(const user : address; const amt : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    s := updateInterest(s);

    const exchangeRate : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) / s.totalSupply;
    const mintTokens : nat = amt / exchangeRate;

    const accountTokens : nat = getTokens(user, s);
    s.accountTokens[user] := accountTokens + mintTokens;
    s.totalSupply := s.totalSupply + mintTokens;
    s.totalLiquid := s.totalLiquid + amt;
  } with (noOperations, s)

function redeem(const user : address; const amt : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    s := updateInterest(s);

    var burnTokens : nat := 0n;
    const accountTokens : nat = getTokens(user, s);
    var exchangeRate : nat := abs(s.totalLiquid + s.totalBorrows - s.totalReserves) / s.totalSupply;

    if exchangeRate = 0n then
      exchangeRate := 1n;
    else skip;

    if amt = 0n then
      burnTokens := accountTokens;
    else
      burnTokens := amt / exchangeRate;

    
    s.accountTokens[user] := abs(accountTokens - burnTokens);
    s.totalSupply := abs(s.totalSupply - burnTokens);
    s.totalLiquid := abs(s.totalLiquid - amt);
  } with (noOperations, s)

function borrow(const user : address; const amt : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    if s.totalLiquid < amt then
      failwith("AmountTooBig")
    else skip;
    s := updateInterest(s);

    var accountBorrows : borrows := getBorrows(user, s);
    accountBorrows.amount := accountBorrows.amount + amt;
    accountBorrows.lastBorrowIndex := s.borrowIndex;

    s.accountBorrows[user] := accountBorrows;
    s.totalBorrows := s.totalBorrows + amt;
  } with (noOperations, s)

function repay(const user : address; const amt : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    s := updateInterest(s);

    var accountBorrows : borrows := getBorrows(user, s);
    accountBorrows.amount := accountBorrows.amount * s.borrowIndex / accountBorrows.lastBorrowIndex;
    accountBorrows.amount := abs(accountBorrows.amount - amt);
    accountBorrows.lastBorrowIndex := s.borrowIndex;

    s.accountBorrows[user] := accountBorrows;
    s.totalBorrows := abs(s.totalBorrows - amt);
  } with (noOperations, s)

function liquidate(const user : address; const borrower : address; var amt : nat;
                   const collateral : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    s := updateInterest(s);
    if user = borrower then
      failwith("BorrowerCannotBeLiquidator")
    else skip;

    var userBorrows : borrows := getBorrows(user, s);
    userBorrows.lastBorrowIndex := s.borrowIndex;
    s.accountBorrows[user] := userBorrows;

    var debtorBorrows : borrows := getBorrows(borrower, s);
    if amt = 0n then
      amt := debtorBorrows.amount
    else skip;


    const hundredPercent : nat = 1000000000n;
    const liquidationIncentive : nat = 1050000000n;// 1050000000 105% (1.05)
    const exchangeRate : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) / s.totalSupply;
    const seizeTokens : nat = amt * liquidationIncentive / hundredPercent / exchangeRate;

    debtorBorrows.amount := abs(debtorBorrows.amount - seizeTokens);

    s.accountBorrows[borrower] := debtorBorrows;
    s.accountTokens[user] := getTokens(user, s) + seizeTokens;
  } with (noOperations, s)

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
    | Liquidate(params) -> liquidate(params.0, params.1, params.2, params.3, s)
  end;
