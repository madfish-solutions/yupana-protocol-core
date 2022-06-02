(* Helper function to get account *)
function getAccount(
  const user            : address;
  const tokenId         : tokenId;
  const accounts     : big_map((address * tokenId), account))
                        : account is
  case accounts[(user, tokenId)] of
    None -> record [
      allowances        = (set [] : set(address));
      borrowF           = 0n;
      lastBorrowIndexF  = 0n;
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
  const tokens          : big_map(tokenId, tokenType))
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
      borrowIndexF            = precision;
      maxBorrowRate           = 0n;
      collateralFactorF       = 0n;
      reserveFactorF          = 0n;
      liquidReserveRateF      = 0n;
      lastPriceFF             = 0n;
      borrowPause             = False;
      enterMintPause          = False;
      isInterestUpdating      = False;
      thresholdF              = 0n;
    ]
  | Some(v) -> v
  end

function get_total_supply(
  const p               : tokenAction;
  const s               : yStorage)
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
  const s               : yStorage)
                        : bool is
  block {
    const operator : address = Tezos.sender;
    const owner : address = transferParam.from_;
    const user : account = getAccount(owner, token_id, s.accounts);
  } with owner = operator or Set.mem(operator, user.allowances)

(* Perform transfers *)
function iterateTransfer(
  const s               : yStorage;
  const params          : transferParam)
                        : yStorage is
  block {
    (* Perform single transfer *)
    function makeTransfer(
      var s             : yStorage;
      const transferDst : transferDestination)
                        : yStorage is
      block {
        (* Check permissions *)
        require(isApprovedOperator(params, transferDst.token_id, s), Errors.FA2.notOperator);

        (* Check the entered markets *)
        require(not Set.mem(transferDst.token_id, getTokenIds(params.from_, s.markets)), Errors.YToken.collateralTaken);

        (* Token id check *)
        require(transferDst.token_id < s.lastTokenId, Errors.FA2.undefined);

        (* Get source info *)
        var srcBalanceF : nat := getBalanceByToken(params.from_, transferDst.token_id, s.ledger);
        const transferAmountF : nat = transferDst.amount * precision;

        (* Update source balance *)
        srcBalanceF := get_nat_or_fail(srcBalanceF - transferAmountF, Errors.FA2.lowBalance);

        s.ledger[(params.from_, transferDst.token_id)] := srcBalanceF;

        (* Get receiver balance *)
        var dstBalanceF : nat := getBalanceByToken(transferDst.to_, transferDst.token_id, s.ledger);

        (* Update destination balance *)
        dstBalanceF := dstBalanceF + transferAmountF;
        s.ledger[(transferDst.to_, transferDst.token_id)] := dstBalanceF;
    } with s
} with List.fold(makeTransfer, params.txs, s)

(* Perform single operator update *)
function iterate_update_operators(
  var s                 : yStorage;
  const params          : updateOperatorParam)
                        : yStorage is
  block {
    case params of
      Add_operator(param) -> block {
      (* Check an owner *)
      require(Tezos.sender = param.owner, Errors.FA2.notOwner);
      require(param.token_id < s.lastTokenId, Errors.FA2.undefined);

      (* Create or get source account *)
      var srcAccount : account := getAccount(param.owner, param.token_id, s.accounts);
      (* Add operator *)
      srcAccount.allowances := Set.add(param.operator, srcAccount.allowances);
      (* Update storage *)
      s.accounts[(param.owner, param.token_id)] := srcAccount;
    }
    | Remove_operator(param) -> block {
      (* Check an owner *)
      require(Tezos.sender = param.owner, Errors.FA2.notOwner);
      require(param.token_id < s.lastTokenId, Errors.FA2.undefined);

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
  const s               : yStorage)
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
              require(request.token_id < s.lastTokenId, Errors.FA2.undefined);
              (* Retrieve the asked account from the storage *)
              const userBalanceF : nat = getBalanceByToken(request.owner, request.token_id, s.ledger);

              (* Form the response *)
              const response : balance_of_response = record [
                  request = request;
                  balance = userBalanceF / precision;
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
  var s                 : yStorage)
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
  var s                 : yStorage)
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
