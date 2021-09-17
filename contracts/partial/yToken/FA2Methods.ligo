(* Helper function to get account *)
function getAccount(
  const user            : address;
  const s               : tokenStorage)
                        : account is
  case s.accountInfo[user] of
    None -> record [
      balances          = (Map.empty : map(tokenId, nat));
      allowances        = (set [] : set(address));
      borrows           = (Map.empty : map(tokenId, nat));
      lastBorrowIndex   = (Map.empty : map(tokenId, nat));
      markets           = (set [] : set(tokenId));
    ]
  | Some(v) -> v
  end

(* Helper function to get token info *)
function getTokenInfo(
  const tokenId         : tokenId;
  const s               : tokenStorage)
                        : tokenInfo is
  case s.tokenInfo[tokenId] of
    None -> record [
      mainToken               = zeroAddress;
      faType                  = FA12(unit);
      interstRateModel        = zeroAddress;
      priceUpdateTime         = zeroTimestamp;
      lastUpdateTime          = zeroTimestamp;
      totalBorrowsFloat       = 0n;
      totalLiquidFloat        = 0n;
      totalSupplyFloat        = 0n;
      totalReservesFloat      = 0n;
      borrowIndex             = accuracy;
      maxBorrowRate           = 0n;
      collateralFactorFloat   = 0n;
      reserveFactorFloat      = 0n;
      lastPrice               = 0n;
    ]
  | Some(v) -> v
  end

function getMapInfo(
  const currentMap      : map(tokenId, nat);
  const tokenId         : nat)
                        : nat is
  case currentMap[tokenId] of
    None -> 0n
  | Some(v) -> v
  end

function getTokenContract(
  const tokenAddress    : address)
                        : contract(transferType) is
  case(
    Tezos.get_entrypoint_opt("%transfer", tokenAddress)
                        : option(contract(transferType))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("token/cant-get-contract-token") : contract(transferType)
    )
  end;

function getIterTranserContract(
  const tokenAddress    : address)
                        : contract(iterTransferType) is
  case(
    Tezos.get_entrypoint_opt("%transfer", tokenAddress)
                        : option(contract(iterTransferType))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("token/cant-get-contract-fa2-token") : contract(iterTransferType)
    )
  end;

function getTotalSupply(
  const p               : tokenAction;
  const s               : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        IGetTotalSupply(args) -> {
          const res : tokenInfo = getTokenInfo(args.token_id, s);
          operations := list [
            Tezos.transaction(res.totalSupplyFloat, 0tz, args.receiver)
          ];
        }
      | _                         -> skip
      end
  } with (operations, s)

(* Helper function to get acount balance by token *)
function getBalanceByToken(
  const user            : account;
  const tokenId         : tokenId)
                        : nat is
  case user.balances[tokenId] of
  | None -> 0n
  | Some(v) -> v
  end

(* Validates the operators for the given transfer batch
 * and the operator storage.
 *)
[@inline] function isApprovedOperator(
  const transferParam   : transferParam;
  const s               : tokenStorage)
                        : bool is
  block {
    const operator : address = Tezos.sender;
    const owner : address = transferParam.from_;
    const user : account = getAccount(owner, s);
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
        (* Create or get source account *)
        var srcAccount : account := getAccount(params.from_, s);

        (* Check permissions *)
        if isApprovedOperator(params, s)
        then skip
        else failwith("yToken/FA2-not-operator");

        (* Check the entered markets *)
        if Set.mem(transferDst.tokenId, srcAccount.markets)
        then failwith("yToken/token-taken-as-collateral")
        else skip;

        (* Token id check *)
        if transferDst.tokenId < s.lastTokenId
        then skip
        else failwith("FA2/token-undefined");

        (* Get source balance *)
        const srcBalance : nat =
          getBalanceByToken(srcAccount, transferDst.tokenId);

        (* Balance check *)
        if srcBalance < transferDst.amount
        then failwith("FA2/insufficient-balance")
        else skip;

        (* Update source balance *)
        srcAccount.balances[transferDst.tokenId] :=
          abs(srcBalance - transferDst.amount);

        (* Update storage *)
        s.accountInfo[params.from_] := srcAccount;

        (* Create or get destination account *)
        var dstAccount : account := getAccount(transferDst.to_, s);

        (* Get receiver balance *)
        const dstBalance : nat =
          getBalanceByToken(dstAccount, transferDst.tokenId);

        (* Update destination balance *)
        dstAccount.balances[transferDst.tokenId] :=
          dstBalance + transferDst.amount;

        (* Update storage *)
        s.accountInfo[transferDst.to_] := dstAccount;
    } with s
} with List.fold(makeTransfer, params.txs, s)

(* Perform single operator update *)
function iterateUpdateOperators(
  var s                 : tokenStorage;
  const params          : updateOperatorParam)
                        : tokenStorage is
  block {
    case params of
      AddOperator(param) -> block {
      (* Check an owner *)
      if Tezos.sender =/= param.owner
      then failwith("FA2/not-owner")
      else skip;

      (* Create or get source account *)
      var srcAccount : account := getAccount(param.owner, s);

      (* Add operator *)
      srcAccount.allowances := Set.add(param.operator, srcAccount.allowances);

      (* Update storage *)
      s.accountInfo[param.owner] := srcAccount;
    }
    | RemoveOperator(param) -> block {
      (* Check an owner *)
      if Tezos.sender =/= param.owner
      then failwith("FA2/not-owner")
      else skip;

      (* Create or get source account *)
      var srcAccount : account := getAccount(param.owner, s);

      (* Remove operator *)
      srcAccount.allowances := Set.remove(
        param.operator,
        srcAccount.allowances
      );

      (* Update storage *)
      s.accountInfo[param.owner] := srcAccount;
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
        IBalanceOf(balanceParams) -> {
          function lookUpBalance(
            const l           : list(balanceOfResponse);
            const request     : balanceOfRequest)
                              : list(balanceOfResponse) is
            block {
              (* Retrieve the asked account from the storage *)
              const user : account = getAccount(request.owner, s);

              (* Form the response *)
              const response : balanceOfResponse = record [
                  request = request;
                  balance = getBalanceByToken(user, request.tokenId);
                ];
            } with response # l;

          (* Collect balances info *)
          const accumulatedResponse : list(balanceOfResponse) =
            List.fold(
              lookUpBalance,
              balanceParams.requests,
              (nil: list(balanceOfResponse))
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

function updateOperators(
  const p               : tokenAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        IUpdateOperators(updateOperatorParams) -> {
          s := List.fold(
            iterateUpdateOperators,
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
