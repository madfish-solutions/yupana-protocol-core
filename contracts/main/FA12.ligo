// FA1.2 CONTRACT FOR TESTING

(* Define types *)
type trusted is address;
type amt is nat;

type account is
  record [
    balance         : amt;
    allowances      : map (trusted, amt);
  ]

(* contract storage *)
type storage is
  record [
    totalSupply     : amt;
    ledger          : big_map (address, account);
  ]

(* define return for readability *)
type return is list (operation) * storage

(* define noop for readability *)
const noOperations : list (operation) = nil;

(* Inputs *)
type transferParams is michelson_pair(
  address,
  "from",
  michelson_pair(address, "to", amt, "value"),
  ""
)
type approveParams is michelson_pair(trusted, "spender", amt, "value")
type balanceParams is michelson_pair(address, "owner", contract(amt), "")
type allowanceParams is michelson_pair(michelson_pair(
    address,
    "owner",
    trusted,
    "spender"
  ), "", contract(amt), "")
type totalSupplyParams is (unit * contract(amt))
type withdrawParams is (nat * unit)

(* Valid entry points *)
type entryAction is
  | Transfer of transferParams
  | Approve of approveParams
  | GetBalance of balanceParams
  | GetAllowance of allowanceParams
  | GetTotalSupply of totalSupplyParams
  | Mint of nat
  | Withdraw of withdrawParams

(* Helper function to get account *)
function getAccount(
  const addr            : address;
  const s               : storage)
                        : account is
  block {
    var acct : account :=
      record [
        balance    = 0n;
        allowances = (map [] : map (address, amt));
      ];
    case s.ledger[addr] of
      None -> skip
    | Some(instance) -> acct := instance
    end;
  } with acct

(* Helper function to get allowance for an account *)
function getAllowance(
  const ownerAccount    : account;
  const spender         : address)
                        : amt is
  case ownerAccount.allowances[spender] of
    Some (amt) -> amt
  | None -> 0n
  end;

(* Transfer token to another account *)
function transfer(
  const from_           : address;
  const to_             : address;
  const value           : amt;
  var s                 : storage)
                        : return is
  block {
    (* Retrieve sender account from storage *)
    var senderAccount : account := getAccount(from_, s);

    (* Balance check *)
    if senderAccount.balance < value then
      failwith("fa12/not-enough-balance")
    else skip;

    (* Check this address can spend the tokens *)
    if from_ =/= Tezos.sender
    then block {
      const spenderAllowance : amt = getAllowance(
        senderAccount,
        Tezos.sender
      );

      if spenderAllowance < value
      then failwith("fa12/not-enough-allowance")
      else skip;
      (* Decrease any allowances *)
      senderAccount.allowances[Tezos.sender] := abs(spenderAllowance - value);
    } else skip;

    (* Update sender balance *)
    senderAccount.balance := abs(senderAccount.balance - value);

    (* Update storage *)
    s.ledger[from_] := senderAccount;

    (* Create or get destination account *)
    var destAccount : account := getAccount(to_, s);

    (* Update destination balance *)
    destAccount.balance := destAccount.balance + value;

    (* Update storage *)
    s.ledger[to_] := destAccount;

  } with (noOperations, s)

(* Approve an amt to be spent by another address in the name of the sender *)
function approve(
  const spender         : address;
  const value           : amt;
  var s                 : storage)
                        : return is
  block {

    (* Create or get sender account *)
    var senderAccount : account := getAccount(Tezos.sender, s);

    (* Get current spender allowance *)
    const spenderAllowance : amt = getAllowance(senderAccount, spender);

    (* Prevent a corresponding attack vector *)
    if spenderAllowance > 0n and value > 0n
    then failwith("fa12/unsafe-allowance-change")
    else skip;

    (* Set spender allowance *)
    senderAccount.allowances[spender] := value;

    (* Update storage *)
    s.ledger[Tezos.sender] := senderAccount;

  } with (noOperations, s)

(* View function that forwards the balance of source to a contract *)
function getBalance(
  const owner           : address;
  const contr           : contract(amt);
  var s                 : storage)
                        : return is
  block {
    const ownerAccount : account = getAccount(owner, s);
  } with (list [transaction(ownerAccount.balance, 0tz, contr)], s)

(* View function that forwards the allowance amt of spender
  in the name of tokenOwner to a contract *)
function getAllowance (
  const owner           : address;
  const spender         : address;
  const contr           : contract(amt);
  var s                 : storage)
                        : return is
  block {
    const ownerAccount : account = getAccount(owner, s);
    const spenderAllowance : amt = getAllowance(ownerAccount, spender);
  } with (list [transaction(spenderAllowance, 0tz, contr)], s)

(* View function that forwards the totalSupply to a contract *)
function getTotalSupply(
  const contr           : contract(amt);
  var s                 : storage)
                        : return is
  block {
    skip
  } with (list [transaction(s.totalSupply, 0tz, contr)], s)

function mint (
  var amt                 : nat;
  var s                   : storage)
                          : return is
  block {
    var senderAccount : account := getAccount(Tezos.sender, s);
    senderAccount.balance := senderAccount.balance + amt;
    s.ledger[Tezos.sender] := senderAccount;
  } with (noOperations, s)

function withdraw(
  const value           : amt;
  var s                 : storage)
                        : return is
  block {
    var senderAccount : account := getAccount(Tezos.sender, s);
    if senderAccount.balance < value then
      failwith("fa12/not-enough-balance")
    else skip;

    senderAccount.balance := abs(senderAccount.balance - value);
    s.ledger[Tezos.sender] := senderAccount;
  } with (list [Tezos.transaction(
      unit,
      value * 1mutez,
      (get_contract(Tezos.sender) : contract(unit))
    )], s)

(* Main entrypoint *)
function main (
  const action          : entryAction;
  var s                 : storage)
                        : return is
  block {
    skip
  } with case action of
    | Transfer(params) -> transfer(params.0, params.1.0, params.1.1, s)
    | Approve(params) -> approve(params.0, params.1, s)
    | GetBalance(params) -> getBalance(params.0, params.1, s)
    | GetAllowance(params) -> getAllowance(params.0.0, params.0.1, params.1, s)
    | GetTotalSupply(params) -> getTotalSupply(params.1, s)
    | Mint(params) -> mint(params, s)
    | Withdraw(params) -> withdraw(params.0, s)
  end;
