type borrows is
  record [
    amount           :nat;
    lastBorrowIndex  :nat;
    allowances       :map (address, nat);
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

type return is list (operation) * storage
[@inline] const noOperations : list (operation) = nil;

type transferParams is michelson_pair(address, "from", michelson_pair(address, "to", nat, "value"), "")
type transfer_type is TransferOuttside of michelson_pair(address, "from", michelson_pair(address, "to", nat, "value"), "")
type approveParams is michelson_pair(address, "spender", nat, "value")
type balanceParams is michelson_pair(address, "owner", contract(nat), "")
type allowanceParams is michelson_pair(michelson_pair(address, "owner", address, "spender"), "", contract(nat), "")
type totalSupplyParams is (unit * contract(nat))

type mintParams is michelson_pair(address, "user", nat, "amount")
type redeemParams is michelson_pair(address, "user", nat, "amount")
type borrowParams is michelson_pair(address, "user", nat, "amount")
type repayParams is michelson_pair(address, "user", nat, "amount")
type liquidateParams is michelson_pair(address, "liquidator", michelson_pair(address, "borrower", nat, "amount"), "")

type entryAction is
  | Transfer of transferParams
  | Approve of approveParams
  | GetBalance of balanceParams
  | GetAllowance of allowanceParams
  | GetTotalSupply of totalSupplyParams
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
        allowances = (map [] : map (address, nat));
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

(* Helper function to get allowance for an account *)
function getAllowance (const borrw : borrows; const spender : address; const s : storage) : nat is
  case borrw.allowances[spender] of
    Some (nat) -> nat
  | None -> 0n
  end;

(* Transfer token to another account *)
function transfer (const from_ : address; const to_ : address; const value : nat; var s : storage) : return is
  block {

    (* Retrieve sender account from storage *)
    const senderAccount : borrows = getBorrows(from_, s);
    const accountTokensFrom : nat = getTokens(from_, s);

    (* Balance check *)
    if accountTokensFrom < value then
      failwith("NotEnoughBalance")
    else skip;

    (* Check this address can spend the tokens *)
    if from_ =/= Tezos.sender then block {
      const spenderAllowance : nat = getAllowance(senderAccount, Tezos.sender, s);

      if spenderAllowance < value then
        failwith("NotEnoughAllowance")
      else skip;

      (* Decrease any allowances *)
      senderAccount.allowances[Tezos.sender] := abs(spenderAllowance - value);
    } else skip;

    (* Update sender balance *)
    accountTokensFrom := abs(accountTokensFrom - value);

    const accountTokensTo : nat = getTokens(from_, s);    
    (* Update destination balance *)
    accountTokensTo := accountTokensTo + value;

  } with (noOperations, s)

(* Approve an nat to be spent by another address in the name of the sender *)
function approve (const spender : address; const value : nat; var s : storage) : return is
  block {

    (* Create or get sender account *)
    var senderAccount : borrows := getBorrows(Tezos.sender, s);

    (* Get current spender allowance *)
    const spenderAllowance : nat = getAllowance(senderAccount, spender, s);

    (* Prevent a corresponding attack vector *)
    if spenderAllowance > 0n and value > 0n then
      failwith("UnsafeAllowanceChange")
    else skip;

    (* Set spender allowance *)
    senderAccount.allowances[spender] := value;

    (* Update storage *)
    s.accountBorrows[Tezos.sender] := senderAccount;

  } with (noOperations, s)

(* View function that forwards the balance of source to a contract *)
function getBalance (const owner : address; const contr : contract(nat); var s : storage) : return is
  block {
    const accountTokens : nat = getTokens(owner, s);
  } with (list [transaction(accountTokens, 0tz, contr)], s)

(* View function that forwards the allowance nat of spender in the name of tokenOwner to a contract *)
function getAllowance (const owner : address; const spender : address; const contr : contract(nat); var s : storage) : return is
  block {
    const ownerAccount : borrows = getBorrows(owner, s);
    const spenderAllowance : nat = getAllowance(ownerAccount, spender, s);
  } with (list [transaction(spenderAllowance, 0tz, contr)], s)

(* View function that forwards the totalSupply to a contract *)
function getTotalSupply (const contr : contract(nat); var s : storage) : return is
  block {
    skip
  } with (list [transaction(s.totalSupply, 0tz, contr)], s)

// function getTokens(const addr : address; const s : storage) : nat is
//   case s.accountTokens[addr] of
//     Some (value) -> value
//   | None -> 0n
//   end;

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
function mint(const user : address; const nat : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    s := updateInterest(s);

    const exchangeRate : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) / s.totalSupply;
    const mintTokens : nat = nat / exchangeRate;

    const accountTokens : nat = getTokens(user, s);
    s.accountTokens[user] := accountTokens + mintTokens;
    s.totalSupply := s.totalSupply + mintTokens;
    s.totalLiquid := s.totalLiquid + nat;
  } with (list [Tezos.transaction(TransferOuttside(user, (Tezos.self_address, nat)), 
         0mutez, 
         getTokenContract(s.token))], s)

function redeem(const user : address; var nat : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    s := updateInterest(s);

    var burnTokens : nat := 0n;
    const accountTokens : nat = getTokens(user, s);
    var exchangeRate : nat := abs(s.totalLiquid + s.totalBorrows - s.totalReserves) / s.totalSupply;

    if exchangeRate = 0n then
      failwith("NotEnoughTokensToSendToUser")
    else skip;

    if nat = 0n then
      nat := accountTokens;
    else skip;
    burnTokens := nat / exchangeRate;

    
    s.accountTokens[user] := abs(accountTokens - burnTokens);
    s.totalSupply := abs(s.totalSupply - burnTokens);
    s.totalLiquid := abs(s.totalLiquid - nat);
  } with (list [Tezos.transaction(TransferOuttside(Tezos.self_address, (user, nat)), 
         0mutez, 
         getTokenContract(s.token))], s)

function borrow(const user : address; const nat : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    if s.totalLiquid < nat then
      failwith("AmountTooBig")
    else skip;
    s := updateInterest(s);

    var accountBorrows : borrows := getBorrows(user, s);
    accountBorrows.amount := accountBorrows.amount + nat;
    accountBorrows.lastBorrowIndex := s.borrowIndex;

    s.accountBorrows[user] := accountBorrows;
    s.totalBorrows := s.totalBorrows + nat;
  } with (list [Tezos.transaction(TransferOuttside(Tezos.self_address, (Tezos.sender, nat)), 
         0mutez, 
         getTokenContract(s.token))], s)

function repay(const user : address; const nat : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    s := updateInterest(s);

    var accountBorrows : borrows := getBorrows(user, s);
    accountBorrows.amount := accountBorrows.amount * s.borrowIndex / accountBorrows.lastBorrowIndex;
    accountBorrows.amount := abs(accountBorrows.amount - nat);
    accountBorrows.lastBorrowIndex := s.borrowIndex;

    s.accountBorrows[user] := accountBorrows;
    s.totalBorrows := abs(s.totalBorrows - nat);
  } with (list [Tezos.transaction(TransferOuttside(Tezos.sender, (Tezos.self_address, nat)), 
         0mutez, 
         getTokenContract(s.token))], s)

function liquidate(const liquidator : address; const borrower : address; var nat : nat; var s : storage) : return is
  block {
    mustBeAdmin(s);
    s := updateInterest(s);
    if liquidator = borrower then
      failwith("BorrowerCannotBeLiquidator")
    else skip;

    var debtorBorrows : borrows := getBorrows(borrower, s);
    if nat = 0n then
      nat := debtorBorrows.amount
    else skip;


    const hundredPercent : nat = 1000000000n;
    const liquidationIncentive : nat = 1050000000n;// 1050000000 105% (1.05)
    const exchangeRate : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) / s.totalSupply;
    const seizeTokens : nat = nat * liquidationIncentive / hundredPercent / exchangeRate;

    debtorBorrows.amount := debtorBorrows.amount * s.borrowIndex / debtorBorrows.lastBorrowIndex;
    debtorBorrows.amount := abs(debtorBorrows.amount - seizeTokens);
    debtorBorrows.lastBorrowIndex := s.borrowIndex;

    s.accountBorrows[borrower] := debtorBorrows;
    s.accountTokens[liquidator] := getTokens(liquidator, s) + seizeTokens;
  } with (list [Tezos.transaction(TransferOuttside(Tezos.sender, (Tezos.self_address, nat)), 
         0mutez,
         getTokenContract(s.token))], s)

function main(const action : entryAction; var s : storage) : return is
  block {
    skip
  } with case action of
    | Transfer(params) -> transfer(params.0, params.1.0, params.1.1, s)
    | Approve(params) -> approve(params.0, params.1, s)
    | GetBalance(params) -> getBalance(params.0, params.1, s)
    | GetAllowance(params) -> getAllowance(params.0.0, params.0.1, params.1, s)
    | GetTotalSupply(params) -> getTotalSupply(params.1, s)
    | SetAdmin(params) -> setAdmin(params, s)
    | SetOwner(params) -> setOwner(params, s)
    | Mint(params) -> mint(params.0, params.1, s)
    | Redeem(params) -> redeem(params.0, params.1, s)
    | Borrow(params) -> borrow(params.0, params.1, s)
    | Repay(params) -> repay(params.0, params.1, s)
    | Liquidate(params) -> liquidate(params.0, params.1.0, params.1.1, s)
  end;
