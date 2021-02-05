#include "../partials/IController.ligo"

function setFactory (const newFactoryAddress: address; const s : fullControllerStorage) : fullReturn is
  block {
    if (Tezos.sender = s.storage.admin) then
      s.storage.factory := newFactoryAddress;
    else skip;
  } with (noOperations, s)

function setUseAction (const idx : nat; const f : useFunc; const s : fullControllerStorage) : fullReturn is
  block {
    case s.useLambdas[idx] of 
      Some(n) -> failwith("Controller/function-set") 
      | None -> s.useLambdas[idx] := f 
    end;
  } with (noOperations, s)

[@inline] function middleController (const p : useAction; const this : address; const s : fullControllerStorage) : fullReturn is
  block {
    const idx : nat = case p of
      | UpdatePrice(updateParams) -> 0n
      | SetOracle(setOracleParams) -> 1n
      | Register(registerParams) -> 2n 
      | UpdateQToken(updateQTokenParams) -> 3n 
      | EnterMarket(addr) -> 4n 
      | ExitMarket(addr) -> 5n
      | SafeMint(safeMintParams) -> 6n
      | SafeRedeem(safeRedeemParams) -> 7n
      // | RedeemMiddle(redeemMiddleParams) -> 8n
      // | EnsuredRedeem(ensuredRedeemParams) -> 9n
      // | SafeBorrow(safeBorrowParams) -> 10n
      // | BorrowMiddle(borrowMiddleParams) -> 11n
      // | EnsuredBorrow(ensuredBorrowParams) -> 12n
      // | SafeRepay(safeRepayParams) -> 13n
      // | SafeLiquidate(safeLiquidateParams) -> 14n
      // | LiquidateMiddle(liquidateMiddleParams) -> 15n
      // | EnsuredLiquidate(ensuredLiquidateParams) -> 16n
    end;

    const res : return = case s.useLambdas[idx] of 
      Some(f) -> f(p, this, s.storage)
      | None -> (failwith("Controller/function-not-set") : return) 
    end;
    s.storage := res.1;
  } with (res.0, s)

[@inline] function mustContainsQTokens (const qToken : address; const s : controllerStorage) : unit is
  block {
    if (s.qTokens contains qToken) then skip
    else failwith("NotContains");
  } with (unit)

[@inline] function mustNotContainsQTokens (const qToken : address; const s : controllerStorage) : unit is
  block {
    if (s.qTokens contains qToken) then
      failwith("Contains")
    else skip;
  } with (unit)

[@inline] function getMintEntrypoint(const tokenAddress : address) : contract(mintType) is
  case (Tezos.get_entrypoint_opt("%mint", tokenAddress) : option(contract(mintType))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetMintEntrypoint") : contract(mintType))
  end;

[@inline] function getRedeemEntrypoint(const tokenAddress : address) : contract(redeemType) is
  case (Tezos.get_entrypoint_opt("%redeem", tokenAddress) : option(contract(redeemType))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetRedeemEntrypoint") : contract(redeemType))
  end;

[@inline] function getRedeemMiddleEntrypoint(const token_address : address) : contract(redeemMiddleParams) is
  case (Tezos.get_entrypoint_opt("%redeemMiddle", token_address) : option(contract(redeemMiddleParams))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetRedeemMiddleEntrypoint") : contract(redeemMiddleParams))
  end;

[@inline] function getUpdateControllerStateEntrypoint(const token_address : address) : contract(updateControllerStateType) is
  case (Tezos.get_entrypoint_opt("%updateControllerState", token_address) : option(contract(updateControllerStateType))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetUpdateControllerStateEntrypoint") : contract(updateControllerStateType))
  end;

[@inline] function getAccountTokens (const user : address; const qToken : address; const s : controllerStorage) : nat is
  case s.accountTokens[(user, qToken)] of
    Some (value) -> value
  | None -> 0n
  end; 

[@inline] function getMarket (const qToken : address; const s : controllerStorage) : market is
  block {
    var m : market := record [
      collateralFactor = 0n;
      lastPrice        = 0n;
      oracle           = ("tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg" : address);
      exchangeRate     = 0n;
    ];
    case s.markets[qToken] of
      None -> skip
    | Some(value) -> m := value
    end;
  } with m

[@inline] function getAccountMembership (const user : address; const s : controllerStorage) : address is
  case s.accountMembership[user] of
    None -> ("tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg" : address)
  | Some (value) -> value
  end;

[@inline] function getAccountBorrows (const user : address; const qToken : address; const s : controllerStorage ) : nat is
  case s.accountBorrows[(user, qToken)] of
    Some (value) -> value
  | None -> 0n
  end;

function updatePrice (const p : useAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> {
      mustContainsQTokens(updateParams.qToken, s);
      
      var m : market := getMarket(updateParams.qToken, s);
      
      // UNCOMENT BEFORE DEPLOY
      // if this =/= m.oracle then
      //   failwith("NorOracle")
      // else skip;

      m.lastPrice := updateParams.price;
      s.markets[updateParams.qToken] := m;
    }
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip 
    | EnterMarket(addr) -> skip
    | ExitMarket(addr) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    // | RedeemMiddle(redeemMiddleParams) -> skip
    // | EnsuredRedeem(ensuredRedeemParams) -> skip
    // | SafeBorrow(safeBorrowParams) -> skip
    // | BorrowMiddle(borrowMiddleParams) -> skip
    // | EnsuredBorrow(ensuredBorrowParams) -> skip
    // | SafeRepay(safeRepayParams) -> skip
    // | SafeLiquidate(safeLiquidateParams) -> skip
    // | LiquidateMiddle(liquidateMiddleParams) -> skip
    // | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function setOracle (const p : useAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> {
      // UNCOMENT BEFORE DEPLOY
      // if this =/= s.admin then
      //   failwith("NotAdmin")
      // else skip;

      var m : market := getMarket(setOracleParams.qToken, s);
      m.oracle := setOracleParams.oracle;
      s.markets[setOracleParams.qToken] := m;
    }
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip 
    | EnterMarket(addr) -> skip
    | ExitMarket(addr) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    // | RedeemMiddle(redeemMiddleParams) -> skip
    // | EnsuredRedeem(ensuredRedeemParams) -> skip
    // | SafeBorrow(safeBorrowParams) -> skip
    // | BorrowMiddle(borrowMiddleParams) -> skip
    // | EnsuredBorrow(ensuredBorrowParams) -> skip
    // | SafeRepay(safeRepayParams) -> skip
    // | SafeLiquidate(safeLiquidateParams) -> skip
    // | LiquidateMiddle(liquidateMiddleParams) -> skip
    // | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function register (const p : useAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> {
      // UNCOMENT BEFORE DEPLOY
      // if Tezos.sender =/= s.factory then
      //   failwith("NotFactory")
      // else skip;

      mustNotContainsQTokens(registerParams.qToken, s);

      s.qTokens := Set.add(registerParams.qToken, s.qTokens);
      s.pairs[registerParams.token] := registerParams.qToken;
    }
    | UpdateQToken(updateQTokenParams) -> skip 
    | EnterMarket(addr) -> skip
    | ExitMarket(addr) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    // | RedeemMiddle(redeemMiddleParams) -> skip
    // | EnsuredRedeem(ensuredRedeemParams) -> skip
    // | SafeBorrow(safeBorrowParams) -> skip
    // | BorrowMiddle(borrowMiddleParams) -> skip
    // | EnsuredBorrow(ensuredBorrowParams) -> skip
    // | SafeRepay(safeRepayParams) -> skip
    // | SafeLiquidate(safeLiquidateParams) -> skip
    // | LiquidateMiddle(liquidateMiddleParams) -> skip
    // | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function updateQToken (const p : useAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> {
      // UNCOMENT BEFORE DEPLOY
      // mustContainsQTokens(this, s);

      var m : market := getMarket(this, s);
      m.exchangeRate := updateQTokenParams.exchangeRate;

      s.accountTokens[(updateQTokenParams.user, this)] := updateQTokenParams.balance;
      s.accountBorrows[(updateQTokenParams.user, this)] := updateQTokenParams.borrow;
      s.markets[this] := m;
    } 
    | EnterMarket(addr) -> skip
    | ExitMarket(addr) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    // | RedeemMiddle(redeemMiddleParams) -> skip
    // | EnsuredRedeem(ensuredRedeemParams) -> skip
    // | SafeBorrow(safeBorrowParams) -> skip
    // | BorrowMiddle(borrowMiddleParams) -> skip
    // | EnsuredBorrow(ensuredBorrowParams) -> skip
    // | SafeRepay(safeRepayParams) -> skip
    // | SafeLiquidate(safeLiquidateParams) -> skip
    // | LiquidateMiddle(liquidateMiddleParams) -> skip
    // | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function enterMarket (const p : useAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | EnterMarket(addr) -> {
      // UNCOMENT BEFORE DEPLOY
      // mustContainsQTokens(addr, s);
      var token : address := getAccountMembership(this, s);

      if token = addr then
        failwith("AlreadyEnter")
      else skip;

      s.accountMembership[this] := addr
    }
    | ExitMarket(addr) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    // | RedeemMiddle(redeemMiddleParams) -> skip
    // | EnsuredRedeem(ensuredRedeemParams) -> skip
    // | SafeBorrow(safeBorrowParams) -> skip
    // | BorrowMiddle(borrowMiddleParams) -> skip
    // | EnsuredBorrow(ensuredBorrowParams) -> skip
    // | SafeRepay(safeRepayParams) -> skip
    // | SafeLiquidate(safeLiquidateParams) -> skip
    // | LiquidateMiddle(liquidateMiddleParams) -> skip
    // | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function exitMarket (const p : useAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | EnterMarket(addr) -> skip
    | ExitMarket(addr) -> {
      // UNCOMENT BEFORE DEPLOY
      // mustContainsQTokens(addr, s);
      var token : address := getAccountMembership(this, s);

      if token =/= addr then
        failwith("NotEnter")
      else skip;

      if getAccountBorrows(this, addr, s) =/= 0n then
        failwith("BorrowsExists")
      else skip;
      
      remove this from map s.accountMembership
    }
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    // | RedeemMiddle(redeemMiddleParams) -> skip
    // | EnsuredRedeem(ensuredRedeemParams) -> skip
    // | SafeBorrow(safeBorrowParams) -> skip
    // | BorrowMiddle(borrowMiddleParams) -> skip
    // | EnsuredBorrow(ensuredBorrowParams) -> skip
    // | SafeRepay(safeRepayParams) -> skip
    // | SafeLiquidate(safeLiquidateParams) -> skip
    // | LiquidateMiddle(liquidateMiddleParams) -> skip
    // | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

// function getUserLiquidity (const p : useAction; const this : address; var s : controllerStorage) : return is
//   block {
//     var operations : list(operation) := list[];
//       case p of
//       | UpdatePrice(updateParams) -> skip
//       | SetOracle(setOracleParams) -> skip
//       | Register(registerParams) -> skip
//       | UpdateQToken(updateQTokenParams) -> skip
//       | EnterMarket(addr) -> skip
//       | ExitMarket(addr) -> skip
//       | GetUserLiquidity(getUserLiquidityParams) -> {
//         var sumCollateral : nat := 0n;
//         var sumBorrow : nat := 0n;
//         var token : address := getAccountMembership(getUserLiquidityParams.user, s);
//         var tokensToDenom : nat := 0n;
//         var m : market := getMarket(token, s);

//         tokensToDenom := m.collateralFactor * m.exchangeRate * m.lastPrice / 1000000000000000000n / 1000000000000000000n;
//         sumCollateral := sumCollateral + tokensToDenom * getAccountTokens(getUserLiquidityParams.user, token, s) / 1000000000000000000n;
//         sumBorrow := sumBorrow + m.lastPrice * getAccountBorrows(getUserLiquidityParams.user, token, s) / 1000000000000000000n;

//         if token = getUserLiquidityParams.qToken then block {
//           sumBorrow := sumBorrow + tokensToDenom * getUserLiquidityParams.redeemTokens;
//           sumBorrow := sumBorrow + m.lastPrice * getUserLiquidityParams.borrowAmount;
//         }
//         else skip;

//         // var returnRecord : getUserLiquidityReturn := record [
//         var surplus : nat := 0n;
//         var shortfail : nat := 0n;
//         // ];

//         if sumCollateral > sumBorrow then
//           surplus := abs(sumCollateral - sumBorrow);
//         else skip;

//         if sumBorrow > sumCollateral then
//           shortfail := abs(sumBorrow - sumCollateral);
//         else skip;

//         operations := list[surplus; shortfail];
//       }
//       // | SafeMint(safeMintParams) -> skip
//       // | SafeRedeem(safeRedeemParams) -> skip
//       // | RedeemMiddle(redeemMiddleParams) -> skip
//       // | EnsuredRedeem(ensuredRedeemParams) -> skip
//       // | SafeBorrow(safeBorrowParams) -> skip
//       // | BorrowMiddle(borrowMiddleParams) -> skip
//       // | EnsuredBorrow(ensuredBorrowParams) -> skip
//       // | SafeRepay(safeRepayParams) -> skip
//       // | SafeLiquidate(safeLiquidateParams) -> skip
//       // | LiquidateMiddle(liquidateMiddleParams) -> skip
//       // | EnsuredLiquidate(ensuredLiquidateParams) -> skip
//       end
//   } with (operations, s)


function safeMint (const p : useAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | EnterMarket(addr) -> skip
    | ExitMarket(addr) -> skip
    | SafeMint(safeMintParams) -> {
      mustContainsQTokens(safeMintParams.qToken, s);

      operations := list [
        Tezos.transaction(record [
            user    = Tezos.sender;
            amount  = safeMintParams.amount;
          ],
          0mutez,
          getMintEntrypoint(safeMintParams.qToken)
        )
      ]
    }
    | SafeRedeem(safeRedeemParams) -> skip
    // | RedeemMiddle(redeemMiddleParams) -> skip
    // | EnsuredRedeem(ensuredRedeemParams) -> skip
    // | SafeBorrow(safeBorrowParams) -> skip
    // | BorrowMiddle(borrowMiddleParams) -> skip
    // | EnsuredBorrow(ensuredBorrowParams) -> skip
    // | SafeRepay(safeRepayParams) -> skip
    // | SafeLiquidate(safeLiquidateParams) -> skip
    // | LiquidateMiddle(liquidateMiddleParams) -> skip
    // | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function safeRedeem (const p : useAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | EnterMarket(addr) -> skip
    | ExitMarket(addr) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> {
      mustContainsQTokens(safeRedeemParams.qToken, s);

      var token : address := getAccountMembership(Tezos.sender, s);

      if token = safeRedeemParams.qToken then block {
        operations := Tezos.transaction(
          UpdateControllerState(Tezos.sender), 
          0mutez, 
          getUpdateControllerStateEntrypoint(token)
        ) # operations;

        operations := Tezos.transaction(
          record [
            user         = Tezos.sender;
            qToken       = safeRedeemParams.qToken;
            redeemTokens = safeRedeemParams.amount;
            borrowAmount = getAccountBorrows(Tezos.sender, safeRedeemParams.qToken, s);
          ],
          0mutez, 
          getRedeemMiddleEntrypoint(Tezos.self_address)
        ) # operations;
      }
      else operations := list [
        Tezos.transaction(
          record [
            user = Tezos.sender;
            amount  = safeRedeemParams.amount;
          ], 
          0mutez, 
          getRedeemEntrypoint(safeRedeemParams.qToken)
        )
      ]
    }
    // | RedeemMiddle(redeemMiddleParams) -> skip
    // | EnsuredRedeem(ensuredRedeemParams) -> skip
    // | SafeBorrow(safeBorrowParams) -> skip
    // | BorrowMiddle(borrowMiddleParams) -> skip
    // | EnsuredBorrow(ensuredBorrowParams) -> skip
    // | SafeRepay(safeRepayParams) -> skip
    // | SafeLiquidate(safeLiquidateParams) -> skip
    // | LiquidateMiddle(liquidateMiddleParams) -> skip
    // | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function main (const p : entryAction; const s : fullControllerStorage) : fullReturn is
  block {
    const this: address = Tezos.self_address;
  } with case p of
      | Use(params)                   -> middleController(params, this, s)
      | SetUseAction(params)          -> setUseAction(params.index, params.func, s)
      | SetFactory(params)            -> setFactory(params, s)
    end
