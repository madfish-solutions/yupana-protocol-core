function getUserAccount(
  const userAddress     : address;
  const s               : tokenStorage)
                        : user is
  block {
    var b : user :=
      record [
        amount          = 0n;
        allowances      = (map [] : map (address, nat));
        borrowAmount    = 0n;
        lastBorrowIndex = 0n;
      ];
    case s.account[userAddress] of
      None -> skip
    | Some(value) -> b := value
    end
  } with b

function getTokenContract(
  const tokenAddress    : address)
                        : contract(transferType) is
  case(
    Tezos.get_entrypoint_opt("%transfer", tokenAddress)
                        : option(contract(transferType))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("CantGetContractToken") : contract(transferType)
    )
  end;

[@inline] function getUseController(
  const tokenAddress    : address)
                        : contract(useControllerParam) is
  case(
    Tezos.get_entrypoint_opt("%useController", tokenAddress)
                        : option(contract(useControllerParam))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("CantGetContractController") : contract(useControllerParam)
    )
  end;

function mustBeOwner(
  const s               : tokenStorage)
                        : unit is
  block {
    if Tezos.sender =/= s.owner
    then failwith("NotOwner")
    else skip;
  } with (unit)

function mustBeAdmin(
  const s               : tokenStorage)
                        : unit is
  block {
    if Tezos.sender =/= s.admin
    then failwith("NotAdmin")
    else skip;
  } with (unit)

function getAllowance(
  const userAccount     : user;
  const spender         : address)
                        : nat is
  case userAccount.allowances[spender] of
    Some (nat) -> nat
  | None -> 0n
  end;

function transfer(
  const p               : tokenAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        ITransfer(transferParams) -> {
          if transferParams.from_ = transferParams.to_
          then failwith("InvalidSelfToSelfTransfer")
          else skip;

          var accountTokensFrom : user := getUserAccount(
            transferParams.from_,
            s
          );

          if accountTokensFrom.borrowAmount =/= 0n
          then failwith("YouHaveBorrow")
          else skip;

          if accountTokensFrom.amount < transferParams.value
          then failwith("NotEnoughBalance")
          else skip;

          if transferParams.from_ =/= Tezos.sender
          then block {
            var spenderAllowance : nat := getAllowance(
              accountTokensFrom,
              Tezos.sender
            );

            if spenderAllowance < transferParams.value
            then failwith("NotEnoughAllowance")
            else skip;

            accountTokensFrom.allowances[Tezos.sender] := abs(
              spenderAllowance - transferParams.value
            );
          } else skip;

          accountTokensFrom.amount := abs(
            accountTokensFrom.amount - transferParams.value
          );

          var accountTokensTo : user := getUserAccount(transferParams.to_, s);
          accountTokensTo.amount := accountTokensTo.amount
            + transferParams.value;

          s.account[transferParams.from_] := accountTokensFrom;
          s.account[transferParams.to_] := accountTokensTo;
        }
      | _                         -> skip
      end
  } with (operations, s)

function approve(
  const p               : tokenAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        IApprove(approveParams)   -> {
          var senderAccount : user := getUserAccount(Tezos.sender, s);
          var spenderAllowance : nat := getAllowance(
            senderAccount,
            approveParams.spender
          );

          if spenderAllowance > 0n and approveParams.value > 0n
          then failwith("UnsafeAllowanceChange")
          else skip;

          senderAccount.allowances[approveParams.spender] := approveParams.value;
          s.account[Tezos.sender] := senderAccount;
        }
      | _                         -> skip
      end
  } with (operations, s)

function getBalance(
  const p               : tokenAction;
  const s               : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        IGetBalance(balanceParams) -> {
          const accountUser : user = getUserAccount(balanceParams.owner, s);
          operations := list [
            transaction(accountUser.amount, 0tz, balanceParams.receiver)
          ];
        }
      | _                         -> skip
      end
  } with (operations, s)

function getAllowance(
  const p               : tokenAction;
  const s               : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        IGetAllowance(allowanceParams) -> {
          const ownerAccount : user = getUserAccount(allowanceParams.owner, s);
          var spenderAllowance : nat := getAllowance(
            ownerAccount,
            allowanceParams.spender
          );
          operations := list [
            transaction(spenderAllowance, 0tz, allowanceParams.receiver)
          ];
        }
      | _                         -> skip
      end
  } with (operations, s)

function getTotalSupply(
  const p               : tokenAction;
  const s               : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        IGetTotalSupply(args) -> {
          operations := list [transaction(s.totalSupply, 0tz, args.1)];
        }
      | _                         -> skip
      end
  } with (operations, s)

function setAdmin(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        SetAdmin(addr) -> {
          mustBeOwner(s);
          s.admin := addr;
        }
      | _                         -> skip
      end
  } with (operations, s)

function setOwner(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        SetOwner(addr) -> {
          mustBeOwner(s);
          s.owner := addr;
        }
      | _                         -> skip
      end
  } with (operations, s)

function updateInterest(
  var s                 : tokenStorage)
                        : tokenStorage is
  block {
    // UNUSED
    // const _apr : nat = 25000000000000000n; // 2.5% (0.025) from accuracy/
    // const _utilizationBase : nat = 200000000000000000n; // 20% (0.2)
    // const _secondsPerYear : nat = 31536000n;

    const reserveFactorFloat : nat = 1000000000000000n;// 0.1% (0.001)
    // utilizationBase / secondsPerYear; 0.000000006341958397
    const utilizationBasePerSecFloat : nat = 6341958397n;
    // apr / secondsPerYear; 0.000000000792744800
    const debtRatePerSecFloat : nat = 792744800n;
    // one div operation with float require accuracy mult
    const utilizationRateFloat : nat = s.totalBorrows * accuracy /
      abs(s.totalLiquid + s.totalBorrows - s.totalReserves);
    // one mult operation with float require accuracy division
    const borrowRatePerSecFloat : nat = utilizationRateFloat *
      utilizationBasePerSecFloat / accuracy + debtRatePerSecFloat;
    const simpleInterestFactorFloat : nat = borrowRatePerSecFloat *
      abs(Tezos.now - s.lastUpdateTime);
    // one mult operation with float require accuracy division
    const interestAccumulatedFloat : nat = simpleInterestFactorFloat *
      s.totalBorrows / accuracy;

    s.totalBorrows := interestAccumulatedFloat + s.totalBorrows;
    // one mult operation with float require accuracy division
    s.totalReserves := interestAccumulatedFloat * reserveFactorFloat /
      accuracy + s.totalReserves;
    // one mult operation with float require accuracy division
    s.borrowIndex := simpleInterestFactorFloat * s.borrowIndex /
      accuracy + s.borrowIndex;
  } with (s)

function mint(
  const p               : useAction;
  var s                 : tokenStorage;
  const this            : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Mint(mintParams) -> {
          mustBeAdmin(s);
          var mintTokens : nat := mintParams.amount * accuracy;

          if s.totalSupply =/= 0n
          then block {
            s := updateInterest(s);
            const exchangeRate : nat = abs(
              s.totalLiquid + s.totalBorrows - s.totalReserves
            ) * accuracy / s.totalSupply;
            mintTokens := mintParams.amount * accuracy * accuracy
              / exchangeRate;
          }
          else skip;

          var userAccount : user := getUserAccount(mintParams.user, s);

          userAccount.amount := userAccount.amount + mintTokens;

          s.account[mintParams.user] := userAccount;
          s.totalSupply := s.totalSupply + mintTokens;
          s.totalLiquid := s.totalLiquid + mintParams.amount * accuracy;

          operations := list [
            Tezos.transaction(
              TransferOutside(record [
                from_ = mintParams.user;
                to_ = this;
                value = mintTokens / accuracy
              ]),
              0mutez,
              getTokenContract(s.token)
            )
          ];
        }
      | _                         -> skip
      end
  } with (operations, s)

function redeem(
  const p               : useAction;
  var s                 : tokenStorage;
  const this            : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Redeem(redeemParams) -> {
          mustBeAdmin(s);
          s := updateInterest(s);

          var accountUser : user := getUserAccount(redeemParams.user, s);
          var exchangeRate : nat := abs(
            s.totalLiquid + s.totalBorrows - s.totalReserves
          ) * accuracy / s.totalSupply;

          if exchangeRate = 0n
          then failwith("NotEnoughTokensToSendToUser")
          else skip;

          var amt : nat := redeemParams.amount;

          if amt = 0n
          then amt := accountUser.amount / accuracy;
          else skip;

          if s.totalLiquid < amt * accuracy
          then failwith("NotEnoughLiquid")
          else skip;

          var burnTokens : nat := amt * accuracy * accuracy / exchangeRate;

          if accountUser.amount < burnTokens
          then failwith("NotEnoughTokensToBurn")
          else skip;

          accountUser.amount := abs(accountUser.amount - burnTokens);
          s.account[redeemParams.user] := accountUser;
          s.totalSupply := abs(s.totalSupply - burnTokens);
          s.totalLiquid := abs(s.totalLiquid - amt * accuracy);

          operations := list [
            Tezos.transaction(
              TransferOutside(record [
                from_ = this;
                to_ = redeemParams.user;
                value = amt / accuracy
              ]),
              0mutez,
              getTokenContract(s.token)
            )
          ]
        }
      | _                         -> skip
      end
  } with (operations, s)

function borrow(
  const p               : useAction;
  var s                 : tokenStorage;
  const this            : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Borrow(borrowParams) -> {
          mustBeAdmin(s);
          var borrowAmount : nat := borrowParams.amount;
          borrowAmount := borrowAmount * accuracy;

          if s.totalLiquid < borrowAmount
          then failwith("AmountTooBig")
          else skip;

          s := updateInterest(s);

          var accountUser : user := getUserAccount(borrowParams.user, s);
          accountUser.borrowAmount := accountUser.borrowAmount + borrowAmount;

          if accountUser.lastBorrowIndex =/= 0n
          then accountUser.borrowAmount := accountUser.borrowAmount *
              s.borrowIndex / accountUser.lastBorrowIndex;
          else skip;

          accountUser.lastBorrowIndex := s.borrowIndex;

          s.account[borrowParams.user] := accountUser;
          s.totalBorrows := s.totalBorrows + borrowAmount;

          s.totalLiquid := abs(s.totalLiquid - borrowAmount);
          // ??? UNUSED
          // const exchangeRate : nat = abs(
          //   s.totalLiquid + s.totalBorrows - s.totalReserves
          // ) / s.totalSupply;

          operations := list [
            Tezos.transaction(
              TransferOutside(record [
                from_ = this;
                to_ = borrowParams.user;
                value = borrowAmount / accuracy
              ]),
              0mutez,
              getTokenContract(s.token)
            )
          ]
        }
      | _                         -> skip
      end
  } with (operations, s)

function repay (
  const p               : useAction;
  var s                 : tokenStorage;
  const this            : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Repay(repayParams) -> {
          mustBeAdmin(s);
          s := updateInterest(s);
          var repayAmount : nat := repayParams.amount;
          repayAmount := repayAmount * accuracy;

          var accountUser : user := getUserAccount(repayParams.user, s);

          if accountUser.lastBorrowIndex =/= 0n
          then accountUser.borrowAmount := accountUser.borrowAmount *
            s.borrowIndex / accountUser.lastBorrowIndex;
          else skip;

          if repayAmount = 0n
          then repayAmount := accountUser.borrowAmount;
          else skip;

          if accountUser.borrowAmount < repayAmount
          then failwith("AmountShouldBeLessOrEqual")
          else skip;

          accountUser.borrowAmount := abs(
            accountUser.borrowAmount - repayAmount
          );
          accountUser.lastBorrowIndex := s.borrowIndex;

          s.account[repayParams.user] := accountUser;
          s.totalBorrows := abs(s.totalBorrows - repayAmount);
          // ?? UNUSED
          // const exchangeRate : nat = abs(
          //   s.totalLiquid + s.totalBorrows - s.totalReserves
          // ) * accuracy / s.totalSupply;

          operations := list [
            Tezos.transaction(
              TransferOutside(record [
                from_ = repayParams.user;
                to_ = this;
                value = repayAmount / accuracy
              ]),
              0mutez,
              getTokenContract(s.token)
            )
          ]
        }
      | _                         -> skip
      end
  } with (operations, s)

function liquidate(
  const p               : useAction;
  var s                 : tokenStorage;
  const this            : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Liquidate(liquidateParams) -> {
          mustBeAdmin(s);
          s := updateInterest(s);

          if liquidateParams.liquidator = liquidateParams.borrower
          then failwith("BorrowerCannotBeLiquidator")
          else skip;

          var accountBorrower : user := getUserAccount(
            liquidateParams.borrower,
            s
          );

          if accountBorrower.borrowAmount = 0n
          then failwith("DebtIsZero");
          else skip;

          var liquidateAmount : nat := liquidateParams.amount;

          if liquidateAmount = 0n
          then liquidateAmount := accountBorrower.borrowAmount
          else liquidateAmount := liquidateAmount * accuracy;

          if accountBorrower.lastBorrowIndex =/= 0n
          then accountBorrower.borrowAmount := accountBorrower.borrowAmount *
            s.borrowIndex / accountBorrower.lastBorrowIndex;
          else skip;

          if accountBorrower.borrowAmount < liquidateAmount
          then failwith("AmountShouldBeLessOrEqual")
          else skip;

          accountBorrower.borrowAmount := abs(
            accountBorrower.borrowAmount - liquidateAmount
          );
          accountBorrower.lastBorrowIndex := s.borrowIndex;
          s.totalBorrows := abs(s.totalBorrows - liquidateAmount);

          s.account[liquidateParams.borrower] := accountBorrower;

          operations := list [
            Tezos.transaction(
              TransferOutside(record [
                from_ = liquidateParams.liquidator;
                to_ = this;
                value = liquidateAmount / accuracy
              ]),
              0mutez,
              getTokenContract(s.token)
            )
          ];
        }
      | _                         -> skip
      end
  } with (operations, s)

function seize(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Seize(seizeParams) -> {
          mustBeAdmin(s);

          const exchangeRateFloat : nat = abs(
            s.totalLiquid + s.totalBorrows - s.totalReserves
          ) * accuracy / s.totalSupply;
          const seizeTokensFloat : nat = seizeParams.amount * accuracy /
            exchangeRateFloat;

          var borrowerTokensFloat : user := getUserAccount(
            seizeParams.borrower,
            s
          );
          var liquidatorAccount : user := getUserAccount(
            seizeParams.liquidator,
            s
          );

          if borrowerTokensFloat.amount < seizeTokensFloat
          then failwith("NotEnoughTokens seize")
          else skip;

          borrowerTokensFloat.amount := abs(
            borrowerTokensFloat.amount - seizeTokensFloat
          );
          s.account[seizeParams.borrower] := borrowerTokensFloat;
          liquidatorAccount.amount := liquidatorAccount.amount +
            seizeTokensFloat;
          s.account[seizeParams.liquidator] := liquidatorAccount;
        }
      | _                         -> skip
      end
  } with (operations, s)

function updateControllerState(
  const p               : useAction;
  var s                 : tokenStorage;
  const _this           : address)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        UpdateControllerState(addr) -> {
          mustBeAdmin(s);
          s := updateInterest(s);

          var userAccount : user := getUserAccount(addr, s);
          const exchangeRate : nat = abs(
            s.totalLiquid + s.totalBorrows - s.totalReserves
          ) / s.totalSupply;

          if userAccount.lastBorrowIndex =/= 0n
          then userAccount.borrowAmount := userAccount.borrowAmount *
            s.borrowIndex / userAccount.lastBorrowIndex;
          else skip;

          userAccount.lastBorrowIndex := s.borrowIndex;

          s.account[addr] := userAccount;

          operations := list [
            Tezos.transaction(
              UpdateQToken(record [
                user          = addr;
                balance       = userAccount.amount;
                borrow        = userAccount.borrowAmount;
                exchangeRate  = exchangeRate;
              ]),
              0mutez,
              getUseController(Tezos.sender)
            )
          ];
        }
        | _                       -> skip
        end
  } with (operations, s)
