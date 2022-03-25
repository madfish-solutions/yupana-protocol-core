#import  "../partial/errors.ligo" "Errors"
#include "../partial/commonHelpers.ligo"
// FA2 CONTRACT FOR TESTING
type token_id is nat

type token_metadata_info is [@layout:comb] record [
  token_id      : token_id;
  token_info    : map(string, bytes);
]

type transfer_destination is [@layout:comb] record [
  to_           : address;
  token_id      : token_id;
  amount        : nat;
]

type transfer_param is [@layout:comb] record [
  from_         : address;
  txs           : list(transfer_destination);
]

type transfer_params is list(transfer_param)

type balance_of_request is [@layout:comb] record [
  owner         : address;
  token_id      : token_id;
]

type balance_of_response is [@layout:comb] record [
  request       : balance_of_request;
  balance       : nat;
]

type balance_params is [@layout:comb] record [
  requests      : list(balance_of_request);
  callback      : contract(list(balance_of_response));
]

type operator_param is [@layout:comb] record [
  owner         : address;
  operator      : address;
  token_id      : token_id;
]

type update_operator_param is
| Add_operator        of operator_param
| Remove_operator     of operator_param

type update_operator_params is list(update_operator_param)

type token_meta_info_t    is [@layout:comb] record [
  token_id                : nat;
  token_info              : map(string, bytes);
]

type upd_meta_param_t     is token_meta_info_t

type account is [@layout:comb] record [
  balances            : map(token_id, nat);
  updated             : timestamp;
  permits             : set(address);
]

type token_info is [@layout:comb] record [
  total_supply        : nat;
]

type fa2_storage is [@layout:comb] record [
  account_info        : big_map(address, account);
  token_info          : big_map(token_id, token_info);
  metadata            : big_map(string, bytes);
  token_metadata      : big_map(token_id, token_metadata_info);
  minters             : set(address);
  admin               : address;
  pending_admin       : address;
  last_token_id       : nat;
]

type new_token_params   is map(string, bytes)

type return is list (operation) * fa2_storage

type asset_param        is [@layout:comb] record [
    token_id              : token_id;
    receiver              : address;
    amount                : nat;
  ]

type asset_params       is list(asset_param)

type fa2_action is
| Create_token            of new_token_params
| Mint_asset              of asset_params
| Transfer                of transfer_params
| Balance_of              of balance_params
| Update_operators        of update_operator_params
| Update_metadata         of upd_meta_param_t

[@inline] const no_operations : list(operation) = nil;

[@inline] const precision : nat = 1000000000000000000n;

(* Helper function to get account *)
function get_account(const user : address; const s : fa2_storage) : account is
  case s.account_info[user] of
  | None -> record [
    balances        = (Map.empty : map(token_id, nat));
    updated         = Tezos.now;
    permits         = (set [] : set(address));
  ]
  | Some(v) -> v
  end

(* Helper function to get token info *)
function get_token_info(const token_id : token_id; const s : fa2_storage) : token_info is
  case s.token_info[token_id] of
  | None -> record [
    total_supply    = 0n;
  ]
  | Some(v) -> v
  end

(* Helper function to get acount balance by token *)
function get_balance_by_token(const user : account; const token_id : token_id) : nat is
  case user.balances[token_id] of
  | None -> 0n
  | Some(v) -> v
  end

(* Perform transfers *)
function iterate_transfer(const s : fa2_storage; const params : transfer_param) : fa2_storage is
  block {
    (* Perform single transfer *)
    function make_transfer(var s : fa2_storage; const transfer_dst : transfer_destination) : fa2_storage is
      block {
        (* Create or get source account *)
        var src_account : account := get_account(params.from_, s);

        (* Check permissions *)
        require(params.from_ = Tezos.sender or src_account.permits contains Tezos.sender, Errors.FA2.notOperator);


        // (* Token id check *)
        require(transfer_dst.token_id < s.last_token_id, Errors.FA2.undefined);


        (* Get source balance *)
        const src_balance : nat = get_balance_by_token(src_account, transfer_dst.token_id);

        (* Balance check *)
        (* Update source balance *)
        src_account.balances[transfer_dst.token_id] := get_nat_or_fail(
          src_balance - transfer_dst.amount,
          Errors.FA2.lowBalance
        );

        (* Update storage *)
        s.account_info[params.from_] := src_account;

        (* Create or get destination account *)
        var dst_account : account := get_account(transfer_dst.to_, s);

        (* Get receiver balance *)
        const dst_balance : nat = get_balance_by_token(dst_account, transfer_dst.token_id);

        (* Update destination balance *)
        dst_account.balances[transfer_dst.token_id] := dst_balance + transfer_dst.amount;

        (* Update storage *)
        s.account_info[transfer_dst.to_] := dst_account;
    } with s
} with List.fold(make_transfer, params.txs, s)

(* Perform single operator update *)
function iterate_update_operators(var s : fa2_storage; const params : update_operator_param) : fa2_storage is
  block {
    case params of
    | Add_operator(param) -> block {
      (* Check an owner *)
      require(Tezos.sender = param.owner, Errors.FA2.notOwner);

      (* Create or get source account *)
      var src_account : account := get_account(param.owner, s);

      (* Add operator *)
      src_account.permits := Set.add(param.operator, src_account.permits);

      (* Update storage *)
      s.account_info[param.owner] := src_account;
    }
    | Remove_operator(param) -> block {
      (* Check an owner *)
      require(Tezos.sender = param.owner, Errors.FA2.notOwner);

      (* Create or get source account *)
      var src_account : account := get_account(param.owner, s);

      (* Remove operator *)
      src_account.permits := Set.remove(param.operator, src_account.permits);

      (* Update storage *)
      s.account_info[param.owner] := src_account;
    }
    end
  } with s

(* Perform balance lookup *)
function get_balance_of(const balance_params : balance_params; const s : fa2_storage) : list(operation) is
  block {
    (* Perform single balance lookup *)
    function look_up_balance(const l: list(balance_of_response); const request : balance_of_request) : list(balance_of_response) is
      block {
        (* Retrieve the asked account from the storage *)
        const user : account = get_account(request.owner, s);

        (* Form the response *)
        var response : balance_of_response := record [
          request = request;
          balance = get_balance_by_token(user, request.token_id);
        ];
      } with response # l;

    (* Collect balances info *)
    const accumulated_response : list(balance_of_response) = List.fold(look_up_balance, balance_params.requests, (nil: list(balance_of_response)));
  } with list [Tezos.transaction(
    accumulated_response,
    0tz,
    balance_params.callback
  )]

function update_operators(const s : fa2_storage; const params : update_operator_params) : fa2_storage is
  List.fold(iterate_update_operators, params, s)

function transfer(const s : fa2_storage; const params : transfer_params) : fa2_storage is
  List.fold(iterate_transfer, params, s)

(* Perform minting new tokens *)
function mint_asset(
  const params          : asset_params;
  const s               : fa2_storage)
                        : fa2_storage is
  block {

    function make_mint(
      var s             : fa2_storage;
      const param       : asset_param)
                        : fa2_storage is
      block {
        require(param.token_id < s.last_token_id, Errors.FA2.undefined);

        (* Get receiver account *)
        var dst_account : account := get_account(param.receiver, s);

        (* Get receiver initial balance *)
        const dst_balance : nat =
          get_balance_by_token(dst_account, param.token_id);

        (* Mint new tokens *)
        dst_account.balances[param.token_id] := dst_balance + param.amount;

        (* Get token info *)
        var token : token_info := get_token_info(param.token_id, s);

        (* Update token total supply *)
        token.total_supply := token.total_supply + param.amount;

        (* Update storage *)
        s.account_info[param.receiver] := dst_account;
        s.token_info[param.token_id] := token;
      } with s
  } with (List.fold(make_mint, params, s))

function create_token(
  const create_params   : new_token_params;
  var s                 : fa2_storage)
                        : fa2_storage is
  block {
    require(s.admin = Tezos.sender, Errors.FA2.notAdmin);

    s.token_metadata[s.last_token_id] := record [
      token_id = s.last_token_id;
      token_info = create_params;
    ];
    s.last_token_id := s.last_token_id + 1n;
  } with s

function update_metadata(
    const params        : upd_meta_param_t;
    var   s             : fa2_storage)
                        : fa2_storage is
  block {
    require(s.admin = Tezos.sender, Errors.FA2.notAdmin);
    s.token_metadata[params.token_id] := params;
  } with s


function main(
  const action          : fa2_action;
  const s               : fa2_storage)
                        : return is
  case action of
  | Create_token(params)              -> (no_operations, create_token(params, s))
  | Mint_asset(params)                -> (no_operations, mint_asset(params, s))
  | Transfer(params)                  -> (no_operations, transfer(s, params))
  | Update_operators(params)          -> (no_operations, update_operators(s, params))
  | Balance_of(params)                -> (get_balance_of(params, s), s)
  | Update_metadata(params)           -> (no_operations, update_metadata(params, s))
  end
