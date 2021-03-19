#include "../partials/IqToken.ligo"

[@inline] function middleToken (const p : tokenAction; const s : fullTokenStorage) :  fullReturn is
block {
    const idx : nat = case p of
      | ITransfer(transferParams) -> 0n
      | IApprove(approveParams) -> 1n
      | IGetBalance(balanceParams) -> 2n 
      | IGetAllowance(allowanceParams) -> 3n 
      | IGetTotalSupply(totalSupplyParams) -> 4n 
    end;
  const res : return = case s.tokenLambdas[idx] of 
    Some(f) -> f(p, s.storage)
    | None -> (failwith("qToken/middleToken/function-not-set") : return) 
  end;
  s.storage := res.1;
} with (res.0, s)

[@inline] function middleUse (const p : useAction; const this : address; const s : fullTokenStorage) : fullReturn is
block {
    const idx : nat = case p of
      | SetAdmin(addr) -> 0n
      | SetOwner(addr) -> 1n
      | Mint(mintParams) -> 2n
      | Redeem(redeemParams) -> 3n
      | Borrow(borrowParams) -> 4n
      | Repay(repayParams) -> 5n
      | Liquidate(liquidateParams) -> 6n
      | Seize(seizeParams) -> 7n
      | UpdateControllerState(addr) -> 8n
    end;
  const res : return = case s.useLambdas[idx] of 
    Some(f) -> f(p, s.storage, this)
    | None -> (failwith("qToken/middleUse/function-not-set") : return)
  end;
  s.storage := res.1;
} with (res.0, s)

[@inline] function getBorrows (const addr : address; const s : tokenStorage) : borrows is
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

[@inline] function getTokens (const addr : address; const s : tokenStorage) : nat is
  case s.accountTokens[addr] of
    Some (value) -> value
  | None -> 0n
  end;

[@inline] function getTokenContract (const tokenAddress : address) : contract(transferType) is 
  case (Tezos.get_entrypoint_opt("%transfer", tokenAddress) : option(contract(transferType))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetContractToken") : contract(transferType))
  end;

[@inline] function getUseController (const tokenAddress : address) : contract(useControllerParam) is 
  case (Tezos.get_entrypoint_opt("%useController", tokenAddress) : option(contract(useControllerParam))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetContractController") : contract(useControllerParam))
  end;

[@inline] function getSeizeEntrypiont (const tokenAddress : address) : contract(seizeParams) is
  case (Tezos.get_entrypoint_opt("%seize", tokenAddress) : option(contract(seizeParams))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetSeizeEntrypiont") : contract(seizeParams))
  end;


[@inline] function mustBeOwner (const s : tokenStorage) : unit is
  block {
    if Tezos.sender =/= s.owner then
      failwith("NotOwner")
    else skip;
  } with (unit)

[@inline] function mustBeAdmin (const s : tokenStorage) : unit is
  block {
    if Tezos.sender =/= s.admin then
      failwith("NotAdmin")
    else skip;
  } with (unit)

function getAllowance (const borrw : borrows; const spender : address; const s : tokenStorage) : nat is
  case borrw.allowances[spender] of
    Some (nat) -> nat
  | None -> 0n
  end;

function transfer (const p : tokenAction; const s : tokenStorage) : return is 
  block {
    var operations : list(operation) := list[];
      case p of
      | ITransfer(args) -> {
        if args.0 = args.1.0 then
          failwith("InvalidSelfToSelfTransfer")
        else skip;

        const accountTokensFrom : nat = getTokens(args.0, s);
        const senderAccount : borrows = getBorrows(args.0, s);

        if senderAccount.amount =/= 0n then 
          failwith("YouHaveBorrow")
        else skip;

        if accountTokensFrom < args.1.1 then
          failwith("NotEnoughBalance")
        else skip;

        if args.0 =/= Tezos.sender then block {
          const spenderAllowance : nat = getAllowance(senderAccount, Tezos.sender, s);

          if spenderAllowance < args.1.1 then
            failwith("NotEnoughAllowance")
          else skip;

          senderAccount.allowances[Tezos.sender] := abs(spenderAllowance - args.1.1);
        } else skip;

        accountTokensFrom := abs(accountTokensFrom - args.1.1);

        const accountTokensTo : nat = getTokens(args.1.0, s);
        accountTokensTo := accountTokensTo + args.1.1;
      }
      | IApprove(approveParams) -> skip
      | IGetBalance(balanceParams) -> skip
      | IGetAllowance(allowanceParams) -> skip
      | IGetTotalSupply(totalSupplyParams) -> skip
    end
  } with (operations, s)

function approve (const p : tokenAction; const s : tokenStorage) : return is
  block {
    var operations : list(operation) := list[];
      case p of
      | ITransfer(transferParams) -> skip
      | IApprove(args) -> {
        var senderAccount : borrows := getBorrows(Tezos.sender, s);
        const spenderAllowance : nat = getAllowance(senderAccount, args.0, s);

        // if spenderAllowance > 0n and args.1 > 0n then
        //   failwith("UnsafeAllowanceChange")
        // else skip;

        senderAccount.allowances[args.0] := args.1;
        s.accountBorrows[Tezos.sender] := senderAccount;
      }
      | IGetBalance(balanceParams) -> skip
      | IGetAllowance(allowanceParams) -> skip
      | IGetTotalSupply(totalSupplyParams) -> skip
    end
  } with (operations, s)

function getBalance (const p : tokenAction; const s : tokenStorage) : return is
  block {
    var operations : list(operation) := list[];
      case p of
      | ITransfer(transferParams) -> skip
      | IApprove(approveParams) -> skip
      | IGetBalance(args) -> {
        const accountTokens : nat = getTokens(args.0, s);
        operations := list [transaction(accountTokens, 0tz, args.1)];
      }
      | IGetAllowance(allowanceParams) -> skip
      | IGetTotalSupply(totalSupplyParams) -> skip
    end
  } with (operations, s)

function getAllowance (const p : tokenAction; const s : tokenStorage) : return is
  block {
    var operations : list(operation) := list[];
      case p of
      | ITransfer(transferParams) -> skip
      | IApprove(approveParams) -> skip
      | IGetBalance(balanceParams) -> skip
      | IGetAllowance(args) -> {
        const ownerAccount : borrows = getBorrows(args.0.0, s);
        const spenderAllowance : nat = getAllowance(ownerAccount, args.0.1, s);
        operations := list [transaction(spenderAllowance, 0tz, args.1)];
      }
      | IGetTotalSupply(totalSupplyParams) -> skip
    end
  } with (operations, s)

function getTotalSupply (const p : tokenAction; const s : tokenStorage) : return is
  block {
    var operations : list(operation) := list[];
      case p of
      | ITransfer(transferParams) -> skip
      | IApprove(approveParams) -> skip
      | IGetBalance(balanceParams) -> skip
      | IGetAllowance(allowanceParams) -> skip
      | IGetTotalSupply(args) -> {
        operations := list [transaction(s.totalSupply, 0tz, args.1)];
      }
    end
  } with (operations, s)

function setAdmin (const p : useAction; const s : tokenStorage; const this: address) : return is
  block {
    var operations : list(operation) := list[];
      case p of
      | SetAdmin(addr) -> {
        mustBeOwner(s);
        s.admin := addr;
      }
      | SetOwner(addr) -> skip
      | Mint(mintParams) -> skip
      | Redeem(redeemParams) -> skip
      | Borrow(borrowParams) -> skip
      | Repay(repayParams) -> skip
      | Liquidate(liquidateParams) -> skip
      | Seize(seizeParams) -> skip
      | UpdateControllerState(addr) -> skip
    end
  } with (operations, s)

function setOwner (const p : useAction; const s : tokenStorage; const this: address) : return is
  block {
    var operations : list(operation) := list[];
      case p of
      | SetAdmin(addr) -> skip
      | SetOwner(addr) -> {
        mustBeOwner(s);
        s.owner := addr;
      }
      | Mint(mintParams) -> skip
      | Redeem(redeemParams) -> skip
      | Borrow(borrowParams) -> skip
      | Repay(repayParams) -> skip
      | Liquidate(liquidateParams) -> skip
      | Seize(seizeParams) -> skip
      | UpdateControllerState(addr) -> skip
    end
  } with (operations, s)

[@inline] function updateInterest (var s : tokenStorage) : tokenStorage is
  block {
    const apr : nat = 25000000000000000n; // 2.5% (0.025) from accuracy
    const utilizationBase : nat = 200000000000000000n; // 20% (0.2)
    const secondsPerYear : nat = 31536000n;
    const reserveFactorFloat : nat = 1000000000000000n;// 0.1% (0.001)
    const utilizationBasePerSecFloat : nat = 6341958397n; // utilizationBase / secondsPerYear; 0.000000006341958397
    const debtRatePerSecFloat : nat = 792744800n; // apr / secondsPerYear; 0.000000000792744800

    const utilizationRateFloat : nat = s.totalBorrows * accuracy / abs(s.totalLiquid + s.totalBorrows - s.totalReserves); // one div operation with float require accuracy mult
    const borrowRatePerSecFloat : nat = utilizationRateFloat * utilizationBasePerSecFloat / accuracy + debtRatePerSecFloat; // one mult operation with float require accuracy division
    const simpleInterestFactorFloat : nat = borrowRatePerSecFloat * abs(Tezos.now - s.lastUpdateTime);
    const interestAccumulatedFloat : nat = simpleInterestFactorFloat * s.totalBorrows / accuracy; // one mult operation with float require accuracy division

    s.totalBorrows := interestAccumulatedFloat + s.totalBorrows;
    s.totalReserves := interestAccumulatedFloat * reserveFactorFloat / accuracy + s.totalReserves; // one mult operation with float require accuracy division
    s.borrowIndex := simpleInterestFactorFloat * s.borrowIndex / accuracy + s.borrowIndex; // one mult operation with float require accuracy division
  } with (s)

function mint (const p : useAction; const s : tokenStorage; const this: address) : return is
  block {
    var operations : list(operation) := list[];
      case p of
      | SetAdmin(addr) -> skip
      | SetOwner(addr) -> skip
      | Mint(mintParams) -> {
        mustBeAdmin(s);
        var mintTokens : nat := mintParams.amount * accuracy;
        
        if s.totalSupply =/= 0n then block {
          s := updateInterest(s);
          const exchangeRate : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) * accuracy / s.totalSupply;
          mintTokens := mintParams.amount * accuracy * accuracy / exchangeRate;
        }
        else skip;

        s.accountTokens[mintParams.user] := getTokens(mintParams.user, s) + mintTokens;
        s.totalSupply := s.totalSupply + mintTokens;
        s.totalLiquid := s.totalLiquid + mintParams.amount * accuracy;

        operations := list [
          Tezos.transaction(
            TransferOuttside(mintParams.user, (this, mintTokens / accuracy)), 
            0mutez,
            getTokenContract(s.token)
          )
        ];
      }
      | Redeem(redeemParams) -> skip
      | Borrow(borrowParams) -> skip
      | Repay(repayParams) -> skip
      | Liquidate(liquidateParams) -> skip
      | Seize(seizeParams) -> skip
      | UpdateControllerState(addr) -> skip
    end
  } with (operations, s)

function redeem (const p : useAction; const s : tokenStorage; const this: address) : return is
  block {
    var operations : list(operation) := list[];
      case p of
      | SetAdmin(addr) -> skip
      | SetOwner(addr) -> skip
      | Mint(mintParams) -> skip
      | Redeem(redeemParams) -> {
        mustBeAdmin(s);
        s := updateInterest(s);

        var burnTokens : nat := 0n;
        const accountTokens : nat = getTokens(redeemParams.user, s);
        var exchangeRate : nat := abs(s.totalLiquid + s.totalBorrows - s.totalReserves) * accuracy / s.totalSupply;

        if exchangeRate = 0n then
          failwith("NotEnoughTokensToSendToUser")
        else skip;

        if redeemParams.amount = 0n then
          redeemParams.amount := accountTokens / accuracy;
        else skip;

        if s.totalLiquid < redeemParams.amount * accuracy then
          failwith("NotEnoughLiquid")
        else skip;

        burnTokens := redeemParams.amount * accuracy * accuracy / exchangeRate;

        if accountTokens < burnTokens then
          failwith("NotEnoughTokensToBurn")
        else skip;
        
        s.accountTokens[redeemParams.user] := abs(accountTokens - burnTokens);
        s.totalSupply := abs(s.totalSupply - burnTokens);
        s.totalLiquid := abs(s.totalLiquid - redeemParams.amount * accuracy);

        operations := list [
          Tezos.transaction(
            TransferOuttside(this, (redeemParams.user, redeemParams.amount / accuracy)),
            0mutez, 
            getTokenContract(s.token)
          )
        ]
      }
      | Borrow(borrowParams) -> skip
      | Repay(repayParams) -> skip
      | Liquidate(liquidateParams) -> skip
      | Seize(seizeParams) -> skip
      | UpdateControllerState(addr) -> skip
    end
  } with (operations, s)

function borrow (const p : useAction; const s : tokenStorage; const this: address) : return is
  block {
    var operations : list(operation) := list[];
      case p of
      | SetAdmin(addr) -> skip
      | SetOwner(addr) -> skip
      | Mint(mintParams) -> skip
      | Redeem(redeemParams) -> skip
      | Borrow(borrowParams) -> {
        mustBeAdmin(s);
        borrowParams.amount := borrowParams.amount * accuracy;

        if s.totalLiquid < borrowParams.amount then
          failwith("AmountTooBig")
        else skip;

        s := updateInterest(s);

        var accountBorrows : borrows := getBorrows(borrowParams.user, s);
        const accountTokens : nat = getTokens(borrowParams.user, s);
        accountBorrows.amount := accountBorrows.amount + borrowParams.amount;
        accountBorrows.lastBorrowIndex := s.borrowIndex;

        s.accountBorrows[borrowParams.user] := accountBorrows;
        s.totalBorrows := s.totalBorrows + borrowParams.amount;

        s.totalLiquid := abs(s.totalLiquid - borrowParams.amount);
        const exchangeRate : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) / s.totalSupply;

        operations := list [
          Tezos.transaction(
            TransferOuttside(this, (borrowParams.user, borrowParams.amount / accuracy)),
            0mutez, 
            getTokenContract(s.token)
          );
          Tezos.transaction(
            UpdateQToken(record [
              user          = borrowParams.user;
              balance       = accountTokens;
              borrow        = accountBorrows.amount;
              exchangeRate  = exchangeRate;
            ]),
            0mutez,
            getUseController(Tezos.sender)
          )
        ]
      }
      | Repay(repayParams) -> skip
      | Liquidate(liquidateParams) -> skip
      | Seize(seizeParams) -> skip
      | UpdateControllerState(addr) -> skip
    end
  } with (operations, s)

function repay (const p : useAction; const s : tokenStorage; const this: address) : return is
  block {
    var operations : list(operation) := list[];
      case p of
      | SetAdmin(addr) -> skip
      | SetOwner(addr) -> skip
      | Mint(mintParams) -> skip
      | Redeem(redeemParams) -> skip
      | Borrow(borrowParams) -> skip
      | Repay(repayParams) -> {
        mustBeAdmin(s);
        s := updateInterest(s);

        repayParams.amount := repayParams.amount * accuracy;

        var accountBorrows : borrows := getBorrows(repayParams.user, s);
        const accountTokens : nat = getTokens(repayParams.user, s);

        if accountBorrows.lastBorrowIndex =/= 0n then
          accountBorrows.amount := accountBorrows.amount * s.borrowIndex / accountBorrows.lastBorrowIndex;
        else skip;

        if accountBorrows.amount < repayParams.amount then
          failwith("AmountShouldBeLessOrEqual")
        else skip;

        accountBorrows.amount := abs(accountBorrows.amount - repayParams.amount);
        accountBorrows.lastBorrowIndex := s.borrowIndex;

        s.accountBorrows[repayParams.user] := accountBorrows;
        s.totalBorrows := abs(s.totalBorrows - repayParams.amount);
        const exchangeRate : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) * accuracy / s.totalSupply;

        operations := list [
          Tezos.transaction(
            TransferOuttside(repayParams.user, (this, repayParams.amount / accuracy)), 
            0mutez, 
            getTokenContract(s.token)
          );
          Tezos.transaction(
            UpdateQToken(record [
              user          = repayParams.user;
              balance       = accountTokens;
              borrow        = accountBorrows.amount;
              exchangeRate  = exchangeRate;
            ]),
            0mutez,
            getUseController(Tezos.sender)
          )
        ]
      }
      | Liquidate(liquidateParams) -> skip
      | Seize(seizeParams) -> skip
      | UpdateControllerState(addr) -> skip
    end
  } with (operations, s)

function liquidate (const p : useAction; const s : tokenStorage; const this: address) : return is
  block {
    var operations : list(operation) := list[];
      case p of
      | SetAdmin(addr) -> skip
      | SetOwner(addr) -> skip
      | Mint(mintParams) -> skip
      | Redeem(redeemParams) -> skip
      | Borrow(borrowParams) -> skip
      | Repay(repayParams) -> skip
      | Liquidate(liquidateParams) -> {
        mustBeAdmin(s);
        s := updateInterest(s);

        if liquidateParams.liquidator = liquidateParams.borrower then
          failwith("BorrowerCannotBeLiquidator")
        else skip;

        var debtorBorrows : borrows := getBorrows(liquidateParams.borrower, s);
        
        if debtorBorrows.amount = 0n then
          failwith("DebtIsZero");
        else skip;

        if liquidateParams.amount = 0n then
          liquidateParams.amount := debtorBorrows.amount
        else
          liquidateParams.amount := liquidateParams.amount * accuracy;

        const liquidationIncentive : nat = 1050000000000000000n; // 105% (1.05) from accuracy
        const exchangeRateFloat : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) * accuracy / s.totalSupply;

        if debtorBorrows.lastBorrowIndex =/= 0n then
          debtorBorrows.amount := debtorBorrows.amount * s.borrowIndex / debtorBorrows.lastBorrowIndex;
        else skip;
        
        if debtorBorrows.amount < liquidateParams.amount then
          failwith("AmountShouldBeLessOrEqual")
        else skip;

        debtorBorrows.amount := abs(debtorBorrows.amount - liquidateParams.amount);
        debtorBorrows.lastBorrowIndex := s.borrowIndex;
        s.totalBorrows := abs(s.totalBorrows - liquidateParams.amount);

        s.accountBorrows[liquidateParams.borrower] := debtorBorrows;

        operations := list [
          Tezos.transaction(
            TransferOuttside(liquidateParams.liquidator, (this, liquidateParams.amount / accuracy)), 
            0mutez,
            getTokenContract(s.token)
          );
          Tezos.transaction(
            SafeSeize(record [
              liquidator       = liquidateParams.liquidator;
              borrower         = liquidateParams.borrower;
              amount           = liquidateParams.amount;
              collateralToken  = liquidateParams.collateralToken;
            ]),
            0mutez,
            getUseController(Tezos.sender)
          )
        ];
      }
      | Seize(seizeParams) -> skip
      | UpdateControllerState(addr) -> skip
      end
  } with (operations, s)

function seize (const p : useAction; const s : tokenStorage; const this: address) : return is
  block {
    var operations : list(operation) := list[];
      case p of
      | SetAdmin(addr) -> skip
      | SetOwner(addr) -> skip
      | Mint(mintParams) -> skip
      | Redeem(redeemParams) -> skip
      | Borrow(borrowParams) -> skip
      | Repay(repayParams) -> skip
      | Liquidate(liquidateParams) -> skip
      | Seize(seizeParams) -> {
        mustBeAdmin(s);

        const exchangeRateFloat : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) * accuracy / s.totalSupply;
        const seizeTokensFloat : nat = seizeParams.amount * accuracy / exchangeRateFloat;

        const borrowerTokensFloat : nat = getTokens(seizeParams.borrower, s);
        if borrowerTokensFloat < seizeTokensFloat then
          failwith("NotEnoughTokens seize")
        else skip;

        s.accountTokens[seizeParams.borrower] := abs(borrowerTokensFloat - seizeTokensFloat);
        s.accountTokens[seizeParams.liquidator] := getTokens(seizeParams.liquidator, s) + seizeTokensFloat;
      }
      | UpdateControllerState(addr) -> skip
      end
  } with (operations, s)

function updateControllerState (const p : useAction; const s : tokenStorage; const this: address) : return is
  block {
    var operations : list(operation) := list[];
      case p of
      | SetAdmin(addr) -> skip
      | SetOwner(addr) -> skip
      | Mint(mintParams) -> skip
      | Redeem(redeemParams) -> skip
      | Borrow(borrowParams) -> skip
      | Repay(repayParams) -> skip
      | Liquidate(liquidateParams) -> skip
      | Seize(seizeParams) -> skip
      | UpdateControllerState(addr) -> {
        mustBeAdmin(s);
        s := updateInterest(s);

        var userBorrows : borrows := getBorrows(addr, s);
        const accountTokens : nat = getTokens(addr, s);
        const exchangeRate : nat = abs(s.totalLiquid + s.totalBorrows - s.totalReserves) / s.totalSupply;

        if userBorrows.lastBorrowIndex =/= 0n then
          userBorrows.amount := userBorrows.amount * s.borrowIndex / userBorrows.lastBorrowIndex;
        else skip;

        userBorrows.lastBorrowIndex := s.borrowIndex;

        s.accountBorrows[addr] := userBorrows;

        operations := list [
          Tezos.transaction(
            UpdateQToken(record [
              user          = addr;
              balance       = accountTokens;
              borrow        = userBorrows.amount;
              exchangeRate  = exchangeRate;
            ]),
            0mutez,
            getUseController(Tezos.sender)
          )
        ];
      }
      end
  } with (operations, s)

function main (const p : entryAction; const s : fullTokenStorage) : fullReturn is
  block {
     const this: address = Tezos.self_address;
  } with case p of
      | Transfer(params)              -> middleToken(ITransfer(params), s)
      | Approve(params)               -> middleToken(IApprove(params), s)
      | GetBalance(params)            -> middleToken(IGetBalance(params), s)
      | GetAllowance(params)          -> middleToken(IGetAllowance(params), s)
      | GetTotalSupply(params)        -> middleToken(IGetTotalSupply(params), s)
      | Use(params)                   -> middleUse(params, this, s)
    end
