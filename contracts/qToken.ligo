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
    accountBorrows  :big_map(address, nat);
    accountTokens   :big_map(address, nat);
  ]


type return is list (operation) * storage
const noOperations : list (operation) = nil;

type entryAction is
  | SetAdmin of (address * unit)
  | SetOwner of (address * unit)
  | UpdateInterest of unit

function getBorrows(const addr : address; const s : storage) : nat is
  case s.accountBorrows[addr] of
    Some (nat) -> nat
  | None -> 0n
  end;

function getTokens(const addr : address; const s : storage) : nat is
  case s.accountTokens[addr] of
    Some (nat) -> nat
  | None -> 0n
  end;

function mustBeOwner(const s : storage) : unit is
  block {
    if Tezos.sender =/= s.owner then
      failwith("NotOwner")
    else skip;
  } with (unit)

function mustBeAdmin(const s : storage) : unit is
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

function updateInterest(var s : storage) : return is
  block {
    const hundredPercent : nat = 1000000000n;
    const apr : nat = 25000000n; // 2.5% (0.025)
    const utilizationBase : nat = 200000000n; // 20% (0.2)
    const secondsPerYear : nat = 31536000n;
    const reserveFactor : nat = 1000000n;// 0.1% (0.001)

    const utilizationBasePerSec : nat = utilizationBase / secondsPerYear; // 0.0000000063419584
    const debtRatePerSec : nat = apr / secondsPerYear; // 0.0000000007927448
    const utilizationRate : nat = s.totalBorrows / abs(s.totalLiquid + s.totalBorrows - s.totalReserves);
    const borrowRatePerSec : nat = utilizationRate * utilizationBasePerSec + debtRatePerSec;
    const simpleInterestFactor : nat = borrowRatePerSec * abs(Tezos.now - s.lastUpdateTime);
    const interestAccumulated : nat = simpleInterestFactor * s.totalBorrows;

    s.totalBorrows := interestAccumulated + s.totalBorrows;
    s.totalReserves := interestAccumulated * reserveFactor + s.totalReserves; // todo reserve
    s.borrowIndex := simpleInterestFactor * s.borrowIndex + s.borrowIndex;
  } with (noOperations, s)

// TODO FOR ALL add total liqudity
// TODO FOR ALL add operations
// TODO FOR ALL CALL updateInterest() before any action
function mint(const user : address; const amt : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);

    const exchangeRate : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) / s.totalSupply;
    const mintTokens : nat = amt / exchangeRate;

    const accountTokens : nat = getTokens(user, s);
    s.accountTokens[user] := accountTokens + mintTokens;
    s.totalSupply := s.totalSupply + mintTokens;
  } with (noOperations, s)

function redeem(const user : address; const amt : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);

    const exchangeRate : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) / s.totalSupply;
    const burnTokens : nat = amt / exchangeRate;

    const accountTokens : nat = getTokens(user, s);
    s.accountTokens[user] := abs(accountTokens - burnTokens);
    s.totalSupply := abs(s.totalSupply - burnTokens);
  } with (noOperations, s)

function borrow(const user : address; const amt : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);

    const accountBorrows : nat = getBorrows(user, s);
    s.accountBorrows[user] := accountBorrows + amt;
    s.totalBorrows := s.totalBorrows + amt;
  } with (noOperations, s)

function repay(const user : address; const amt : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);

    const accountBorrows : nat = getBorrows(user, s);
    s.accountBorrows[user] := abs((accountBorrows * s.borrowIndex) - amt); 
    s.totalBorrows := abs(s.totalBorrows - amt);
  } with (noOperations, s)

function liquidate(const user : address; const borrower : address; const amt : nat;
                   const collateral : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);

    // if amt == 0 // todo

    const liquidationIncentive : nat = 1050000000n;// 1050000000 105% (1.05)
    const exchangeRate : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) / s.totalSupply;
    const seizeTokens : nat = amt * liquidationIncentive / exchangeRate;

    
    //mock
    s.totalBorrows := 1n;
  } with (noOperations, s)

function main(const action : entryAction; var s : storage) : return is
  block {
    skip
  } with case action of
    | SetAdmin(params) -> setAdmin(params.0, s)
    | SetOwner(params) -> setOwner(params.0, s)
    | UpdateInterest -> updateInterest(s)
  end;