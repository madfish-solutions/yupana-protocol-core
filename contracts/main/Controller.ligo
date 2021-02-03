#include "../partials/IController.ligo"

function setFactory (const newFecAddress: address; const s : fullControllerStorage) : fullReturn is
  block {
    if (Tezos.sender = s.storage.admin) then
      s.storage.factory := newFecAddress;
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
      // | GetUserLiquidity(getUserLiquidityParams) -> 6n
      // | SafeMint(safeMintParams) -> 7n
      // | SafeRedeem(safeRedeemParams) -> 8n
      // | RedeemMiddle(redeemMiddleParams) -> 9n
      // | EnsuredRedeem(ensuredRedeemParams) -> 10n
      // | SafeBorrow(safeBorrowParams) -> 11n
      // | BorrowMiddle(borrowMiddleParams) -> 12n
      // | EnsuredBorrow(ensuredBorrowParams) -> 13n
      // | SafeRepay(safeRepayParams) -> 14n
      // | SafeLiquidate(safeLiquidateParams) -> 15n
      // | LiquidateMiddle(liquidateMiddleParams) -> 16n
      // | EnsuredLiquidate(ensuredLiquidateParams) -> 17n
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

        if this =/= m.oracle then
          failwith("NorOracle")
        else skip;

        m.lastPrice := updateParams.price;
        s.markets[updateParams.qToken] := m;
      }
      | SetOracle(setOracleParams) -> skip
      | Register(registerParams) -> skip
      | UpdateQToken(updateQTokenParams) -> skip 
      | EnterMarket(addr) -> skip
      | ExitMarket(addr) -> skip
      // | GetUserLiquidity(getUserLiquidityParams) -> skip
      // | SafeMint(safeMintParams) -> skip
      // | SafeRedeem(safeRedeemParams) -> skip
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
        if this =/= s.admin then
          failwith("NotAdmin")
        else skip;

        var m : market := getMarket(setOracleParams.qToken, s);
        m.oracle := setOracleParams.oracle;
        s.markets[setOracleParams.qToken] := m;
      }
      | Register(registerParams) -> skip
      | UpdateQToken(updateQTokenParams) -> skip 
      | EnterMarket(addr) -> skip
      | ExitMarket(addr) -> skip
      // | GetUserLiquidity(getUserLiquidityParams) -> skip
      // | SafeMint(safeMintParams) -> skip
      // | SafeRedeem(safeRedeemParams) -> skip
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
          if Tezos.sender =/= s.factory then
            failwith("NotFactory")
          else skip;

          mustNotContainsQTokens(registerParams.qToken, s);

          s.qTokens := Set.add(registerParams.qToken, s.qTokens);
          s.pairs[registerParams.token] := registerParams.qToken;
        }
        | UpdateQToken(updateQTokenParams) -> skip 
        | EnterMarket(addr) -> skip
        | ExitMarket(addr) -> skip
        // | GetUserLiquidity(getUserLiquidityParams) -> skip
        // | SafeMint(safeMintParams) -> skip
        // | SafeRedeem(safeRedeemParams) -> skip
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
        mustContainsQTokens(this, s);

        var m : market := getMarket(this, s);
        m.exchangeRate := updateQTokenParams.exchangeRate;

        s.accountTokens[(updateQTokenParams.user, this)] := updateQTokenParams.balance;
        s.accountBorrows[(updateQTokenParams.user, this)] := updateQTokenParams.borrow;
        s.markets[this] := m;
      } 
      | EnterMarket(addr) -> skip
      | ExitMarket(addr) -> skip
      // | GetUserLiquidity(getUserLiquidityParams) -> skip
      // | SafeMint(safeMintParams) -> skip
      // | SafeRedeem(safeRedeemParams) -> skip
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
        mustContainsQTokens(addr, s);
        var token : address := getAccountMembership(this, s);

        if token = addr then
          failwith("AlreadyEnter")
        else skip;

        s.accountMembership[this] := addr
      }
      | ExitMarket(addr) -> skip
      // | GetUserLiquidity(getUserLiquidityParams) -> skip
      // | SafeMint(safeMintParams) -> skip
      // | SafeRedeem(safeRedeemParams) -> skip
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
        mustContainsQTokens(addr, s);
        var token : address := getAccountMembership(this, s);

        if token =/= addr then
          failwith("NotEnter")
        else skip;

        if getAccountBorrows(this, addr, s) =/= 0n then
          failwith("BorrowsExists")
        else skip;
        
        remove this from map s.accountMembership
      }
      // | GetUserLiquidity(getUserLiquidityParams) -> skip
      // | SafeMint(safeMintParams) -> skip
      // | SafeRedeem(safeRedeemParams) -> skip
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
