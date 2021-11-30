(* Helper function to get account *)
function getAccount(
  const user            : address;
  const tokenId         : tokenId;
  const accounts     : big_map((address * tokenId), account))
                        : account is
  case accounts[(user, tokenId)] of
    None -> record [
      allowances        = (set [] : set(address));
      borrow            = 0n;
      lastBorrowIndex   = 0n;
    ]
  | Some(v) -> v
  end

function getTokenIds(
  const user            : address;
  const addressMap      : big_map(address, set(tokenId)))
                        : set(tokenId) is
  case addressMap[user] of
    None -> (set [] : set(tokenId))
  | Some(v) -> v
  end

(* Helper function to get token info *)
function getToken(
  const token_id        : tokenId;
  const tokens          : map(tokenId, tokenType))
                        : tokenType is
  case tokens[token_id] of
    None -> record [
      mainToken               = FA12(zeroAddress);
      interestRateModel       = zeroAddress;
      priceUpdateTime         = zeroTimestamp;
      interestUpdateTime      = zeroTimestamp;
      totalBorrowsF           = 0n;
      totalLiquidF            = 0n;
      totalSupplyF            = 0n;
      totalReservesF          = 0n;
      borrowIndex             = precision;
      maxBorrowRate           = 0n;
      collateralFactorF       = 0n;
      reserveFactorF          = 0n;
      lastPrice               = 0n;
      borrowPause             = False;
      isInterestUpdating      = False;
    ]
  | Some(v) -> v
  end

function get_total_supply(
  const p               : tokenAction;
  const s               : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        IGet_total_supply(args) -> {
          const res : tokenType = getToken(args.token_id, s.tokens);
          operations := list [
            Tezos.transaction(res.totalSupplyF / precision, 0tz, args.receiver)
          ];
        }
      | _                         -> skip
      end
  } with (operations, s)

(* Helper function to get acount balance by token *)
function getBalanceByToken(
  const user            : address;
  const token_id        : nat;
  const ledger          : big_map((address * tokenId), nat))
                        : nat is
  case ledger[(user, token_id)] of
    None -> 0n
  | Some(v) -> v
  end

(* Validates the operators for the given transfer batch
 * and the operator storage.
 *)
[@inline] function isApprovedOperator(
  const transferParam   : transferParam;
  const token_id        : nat;
  const s               : tokenStorage)
                        : bool is
  block {
    const operator : address = Tezos.sender;
    const owner : address = transferParam.from_;
    const user : account = getAccount(owner, token_id, s.accounts);
  } with owner = operator or Set.mem(operator, user.allowances)

(* Perform transfers *)
function iterateTransfer(
  const s               : tokenStorage;
  const params          : transferParam)
                        : tokenStorage is
  block {
    (* Perform single transfer *)
    function makeTransfer(
      var s             : tokenStorage;
      const transferDst : transferDestination)
                        : tokenStorage is
      block {
        (* Check permissions *)
        if isApprovedOperator(params, transferDst.token_id, s)
        then skip
        else failwith("FA2_NOT_OPERATOR");

        (* Check the entered markets *)
        if Set.mem(transferDst.token_id, getTokenIds(params.from_, s.markets))
        then failwith("yToken/token-taken-as-collateral")
        else skip;

        (* Token id check *)
        if transferDst.token_id >= s.lastTokenId
        then failwith("FA2_TOKEN_UNDEFINED");
        else skip;

        (* Get source info *)
        var srcBalance : nat := getBalanceByToken(params.from_, transferDst.token_id, s.ledger);
        const transferAmountF : nat = transferDst.amount * precision;

        (* Balance check *)
        if srcBalance < transferAmountF
        then failwith("FA2_INSUFFICIENT_BALANCE")
        else skip;

        (* Update source balance *)
        srcBalance :=
          case is_nat(srcBalance - transferAmountF) of
            | None -> (failwith("underflow/srcBalance") : nat)
            | Some(value) -> value
          end;

        s.ledger[(params.from_, transferDst.token_id)] := srcBalance;

        (* Get receiver balance *)
        var dstBalance : nat := getBalanceByToken(transferDst.to_, transferDst.token_id, s.ledger);

        (* Update destination balance *)
        dstBalance := dstBalance + transferAmountF;
        s.ledger[(transferDst.to_, transferDst.token_id)] := dstBalance;
    } with s
} with List.fold(makeTransfer, params.txs, s)

(* Perform single operator update *)
function iterate_update_operators(
  var s                 : tokenStorage;
  const params          : updateOperatorParam)
                        : tokenStorage is
  block {
    case params of
      Add_operator(param) -> block {
      (* Check an owner *)
      if Tezos.sender =/= param.owner
      then failwith("FA2_NOT_OWNER")
      else skip;
      if param.token_id >= s.lastTokenId
      then failwith("FA2_TOKEN_UNDEFINED");
      else skip;

      (* Create or get source account *)
      var srcAccount : account := getAccount(param.owner, param.token_id, s.accounts);
      (* Add operator *)
      srcAccount.allowances := Set.add(param.operator, srcAccount.allowances);
      (* Update storage *)
      s.accounts[(param.owner, param.token_id)] := srcAccount;
    }
    | Remove_operator(param) -> block {
      (* Check an owner *)
      if Tezos.sender =/= param.owner
      then failwith("FA2_NOT_OWNER")
      else skip;
      if param.token_id >= s.lastTokenId
      then failwith("FA2_TOKEN_UNDEFINED");
      else skip;

      (* Create or get source account *)
      var srcAccount : account := getAccount(param.owner, param.token_id, s.accounts);
      (* Remove operator *)
      srcAccount.allowances := Set.remove(
        param.operator,
        srcAccount.allowances
      );
      (* Update storage *)
      s.accounts[(param.owner, param.token_id)] := srcAccount;
    }
    end
  } with s

function getBalance(
  const p               : tokenAction;
  const s               : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        IBalance_of(balanceParams) -> {
          function lookUpBalance(
            const l           : list(balance_of_response);
            const request     : balance_of_request)
                              : list(balance_of_response) is
            block {
              (* Retrieve the asked account from the storage *)
              const userBalance : nat = getBalanceByToken(request.owner, request.token_id, s.ledger);

              (* Form the response *)
              const response : balance_of_response = record [
                  request = request;
                  balance = userBalance / precision;
                ];
            } with response # l;

          (* Collect balances info *)
          const accumulatedResponse : list(balance_of_response) =
            List.fold(
              lookUpBalance,
              balanceParams.requests,
              (nil: list(balance_of_response))
            );
          operations := list [Tezos.transaction(
            accumulatedResponse,
            0tz,
            balanceParams.callback
          )]
        }
      | _                         -> skip
      end
  } with (operations, s)

function update_operators(
  const p               : tokenAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        IUpdate_operators(updateOperatorParams) -> {
          s := List.fold(
            iterate_update_operators,
            updateOperatorParams,
            s
          )
        }
      | _                         -> skip
      end
  } with (operations, s)

function transfer(
  const p               : tokenAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        ITransfer(transferParams) -> {
          s := List.fold(iterateTransfer, transferParams, s)
        }
      | _                         -> skip
      end
  } with (operations, s)
