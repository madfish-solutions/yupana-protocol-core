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
    const apr : nat = 25000000n; //2.5% (0.025)
    const utilizationBase : nat = 200000000n; //20% (0.2)
    const secondsPerYear : nat = 31536000n;

    const utilizationBasePerSec : nat = utilizationBase / secondsPerYear; // 0.0000000063419584
    const debtRatePerSec : nat = apr / secondsPerYear; // 0.0000000007927448
    const utilizationRate : nat = s.totalBorrows / abs(s.totalLiquid + s.totalBorrows - s.totalReserves);
    const borrowRatePerSec : nat = utilizationRate * utilizationBasePerSec + debtRatePerSec;
    const simpleInterestFactor : nat = borrowRatePerSec * 1n;//deltaTime; // what is delta time?
    const interestAccumulated : nat = simpleInterestFactor * s.totalBorrows;

    s.totalBorrows := interestAccumulated + s.totalBorrows;
    s.totalReserves := interestAccumulated + s.totalReserves; // todo reserve
    s.borrowIndex := simpleInterestFactor * s.borrowIndex + s.borrowIndex;
  } with (noOperations, s)

// function mint(const receiver : address; const amount : nat; var s : storage) : return is
//   block {

//   } with (noOperations, s)

function main(const action : entryAction; var s : storage) : return is
  block {
    skip
  } with case action of
    | SetAdmin(params) -> setAdmin(params.0, s)
    | SetOwner(params) -> setOwner(params.0, s)
    | UpdateInterest -> updateInterest(s)
  end;