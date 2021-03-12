#include "../partials/IController.ligo"

function setFactory (const newFactoryAddress: address; const s : fullControllerStorage) : fullReturn is
  block {
    if (Tezos.sender = s.storage.admin) then
      s.storage.factory := newFactoryAddress;
    else failwith("YouNotAdmin");
  } with (noOperations, s)

function setUseAction (const idx : nat; const f : useControllerFunc; const s : fullControllerStorage) : fullReturn is
  block {
    case s.useControllerLambdas[idx] of 
      Some(n) -> failwith("Controller/function-set") 
      | None -> s.useControllerLambdas[idx] := f 
    end;
  } with (noOperations, s)

[@inline] function middleController (const p : useControllerAction; const this : address; const s : fullControllerStorage) : fullReturn is
  block {
    const idx : nat = case p of
      | UpdatePrice(updateParams) -> 0n
      | SetOracle(setOracleParams) -> 1n
      | Register(registerParams) -> 2n 
      | UpdateQToken(updateQTokenParams) -> 3n 
      | ExitMarket(membershipParams) -> 4n
      | SafeMint(safeMintParams) -> 5n
      | SafeRedeem(safeRedeemParams) -> 6n
      | RedeemMiddle(redeemMiddleParams) -> 7n
      | EnsuredRedeem(ensuredRedeemParams) -> 8n
      | SafeBorrow(safeBorrowParams) -> 9n
      | BorrowMiddle(borrowMiddleParams) -> 10n
      | EnsuredBorrow(ensuredBorrowParams) -> 11n
      | SafeRepay(safeRepayParams) -> 12n
      | SafeLiquidate(safeLiquidateParams) -> 13n
      | LiquidateMiddle(liquidateMiddleParams) -> 14n
      | EnsuredLiquidate(ensuredLiquidateParams) -> 15n
    end;

    const res : return = case s.useControllerLambdas[idx] of 
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

[@inline] function getUseEntrypoint(const tokenAddress : address) : contract(useParam) is
  case (Tezos.get_entrypoint_opt("%use", tokenAddress) : option(contract(useParam))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetUseEntrypoint") : contract(useParam))
  end;

[@inline] function getRedeemMiddleEntrypoint(const tokenAddress : address) : contract(redeemMiddleParams) is
  case (Tezos.get_entrypoint_opt("%redeemMiddle", tokenAddress) : option(contract(redeemMiddleParams))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetRedeemMiddleEntrypoint") : contract(redeemMiddleParams))
  end;

[@inline] function getUpdateControllerStateEntrypoint(const tokenAddress : address) : contract(updateControllerStateType) is
  case (Tezos.get_entrypoint_opt("%updateControllerState", tokenAddress) : option(contract(updateControllerStateType))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetUpdateControllerStateEntrypoint") : contract(updateControllerStateType))
  end;

[@inline] function getEnsuredRedeemEntrypoint(const tokenAddress : address) : contract(ensuredRedeemParams) is
  case (Tezos.get_entrypoint_opt("%ensuredRedeem", tokenAddress) : option(contract(ensuredRedeemParams))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetEnsuredRedeemEntrypoint") : contract(ensuredRedeemParams))
  end;

[@inline] function getBorrowMiddleEntrypoint(const tokenAddress : address) : contract(borrowMiddleParams) is
  case (Tezos.get_entrypoint_opt("%borrowMiddle", tokenAddress) : option(contract(borrowMiddleParams))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetBorrowMiddleEntrypoint") : contract(borrowMiddleParams))
  end;

[@inline] function getEnsuredBorrowEntrypoint(const tokenAddress : address) : contract(ensuredBorrowParams) is
  case (Tezos.get_entrypoint_opt("%ensuredBorrow", tokenAddress) : option(contract(ensuredBorrowParams))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetEnsuredBorrowEntrypoint") : contract(ensuredBorrowParams))
  end;

[@inline] function getLiquidateMiddleEntrypoint(const tokenAddress : address) : contract(liquidateMiddleParams) is
  case (Tezos.get_entrypoint_opt("%liquidateMiddle", tokenAddress) : option(contract(liquidateMiddleParams))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetLiquidateMiddleEntrypoint") : contract(liquidateMiddleParams))
  end;

[@inline] function getEnsuredLiquidateEntrypoint(const tokenAddress : address) : contract(ensuredLiquidateParams) is
  case (Tezos.get_entrypoint_opt("%ensuredLiquidate", tokenAddress) : option(contract(ensuredLiquidateParams))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetEnsuredLiquidateEntrypoint") : contract(ensuredLiquidateParams))
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

[@inline] function getAccountMembership (const user : address; const s : controllerStorage) : membershipParams is
  case s.accountMembership[user] of
    Some (value) -> value
  | None -> (record [borrowerToken = ("tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg" : address); collateralToken = ("tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg" : address)])
  end;

[@inline] function getAccountBorrows (const user : address; const qToken : address; const s : controllerStorage ) : nat is
  case s.accountBorrows[(user, qToken)] of
    Some (value) -> value
  | None -> 0n
  end;

function getUserLiquidity (const user : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : controllerStorage) : getUserLiquidityReturn is
  block {
    var sumCollateral : nat := 0n;
    var sumBorrow : nat := 0n;
    var tokens : membershipParams := getAccountMembership(user, s);
    var tokensToDenom : nat := 0n;
    var m : market := getMarket(qToken, s);

    tokensToDenom := m.collateralFactor * m.exchangeRate * m.lastPrice / accuracy / accuracy;
    sumCollateral := sumCollateral + tokensToDenom * getAccountTokens(user, tokens.collateralToken, s) / accuracy;
    sumBorrow := sumBorrow + m.lastPrice * getAccountBorrows(user, tokens.borrowerToken, s) / accuracy;

    if tokens.collateralToken = qToken then block {
      sumBorrow := sumBorrow + tokensToDenom * redeemTokens;
      sumBorrow := sumBorrow + m.lastPrice * borrowAmount;
    }
    else skip;

    var response : getUserLiquidityReturn := 
    record [
      surplus   = 0n;
      shortfail = 0n;
    ];

    if sumCollateral > sumBorrow then
      response.surplus := abs(sumCollateral - sumBorrow);
    else skip;

    if sumBorrow > sumCollateral then
      response.shortfail := abs(sumBorrow - sumCollateral);
    else skip;

  } with (response)

function updatePrice (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> {
      mustContainsQTokens(updateParams.qToken, s);
      
      var m : market := getMarket(updateParams.qToken, s);
      
      if Tezos.sender =/= m.oracle then
        failwith("NotOracle")
      else skip;

      m.lastPrice := updateParams.price;
      s.markets[updateParams.qToken] := m;
    }
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(membershipParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | RedeemMiddle(redeemMiddleParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | BorrowMiddle(borrowMiddleParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | LiquidateMiddle(liquidateMiddleParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function setOracle (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> {
      if Tezos.sender =/= s.admin then
        failwith("NotAdmin")
      else skip;

      var m : market := getMarket(setOracleParams.qToken, s);
      m.oracle := setOracleParams.oracle;
      s.markets[setOracleParams.qToken] := m;
    }
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(membershipParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | RedeemMiddle(redeemMiddleParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | BorrowMiddle(borrowMiddleParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | LiquidateMiddle(liquidateMiddleParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function register (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
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
    | ExitMarket(membershipParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | RedeemMiddle(redeemMiddleParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | BorrowMiddle(borrowMiddleParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | LiquidateMiddle(liquidateMiddleParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function updateQToken (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> {
      mustContainsQTokens(Tezos.sender, s);

      var m : market := getMarket(Tezos.sender, s);
      m.exchangeRate := updateQTokenParams.exchangeRate;

      s.accountTokens[(updateQTokenParams.user, Tezos.sender)] := updateQTokenParams.balance;
      s.accountBorrows[(updateQTokenParams.user, Tezos.sender)] := updateQTokenParams.borrow;
      s.markets[this] := m;
    } 
    | ExitMarket(membershipParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | RedeemMiddle(redeemMiddleParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | BorrowMiddle(borrowMiddleParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | LiquidateMiddle(liquidateMiddleParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function exitMarket (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(membershipParams) -> {
      mustContainsQTokens(membershipParams.borrowerToken, s);
      mustContainsQTokens(membershipParams.collateralToken, s);
  
      var tokens : membershipParams := getAccountMembership(Tezos.sender, s);

      if getAccountBorrows(Tezos.sender, tokens.borrowerToken, s) =/= 0n then
        failwith("BorrowsExists")
      else skip;
      
      remove Tezos.sender from map s.accountMembership
    }
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | RedeemMiddle(redeemMiddleParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | BorrowMiddle(borrowMiddleParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | LiquidateMiddle(liquidateMiddleParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function safeMint (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(membershipParams) -> skip
    | SafeMint(safeMintParams) -> {
      mustContainsQTokens(safeMintParams.qToken, s);

      operations := list [
        Tezos.transaction(
          Mint(record [
            user    = Tezos.sender;
            amount  = safeMintParams.amount;
          ]),
          0mutez,
          getUseEntrypoint(safeMintParams.qToken)
        )
      ];
    }
    | SafeRedeem(safeRedeemParams) -> skip
    | RedeemMiddle(redeemMiddleParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | BorrowMiddle(borrowMiddleParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | LiquidateMiddle(liquidateMiddleParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function safeRedeem (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(membershipParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> {
      mustContainsQTokens(safeRedeemParams.qToken, s);

      var tokens : membershipParams := getAccountMembership(Tezos.sender, s);

      if tokens.collateralToken = safeRedeemParams.qToken then block {
        operations := list [
          Tezos.transaction(
            QUpdateControllerState(Tezos.sender), 
            0mutez, 
            getUpdateControllerStateEntrypoint(tokens.collateralToken)
          );
          Tezos.transaction(
            record [
              user         = Tezos.sender;
              qToken       = safeRedeemParams.qToken;
              redeemTokens = safeRedeemParams.amount;
              borrowAmount = getAccountBorrows(Tezos.sender, safeRedeemParams.qToken, s);
            ],
            0mutez, 
            getRedeemMiddleEntrypoint(this)
          )
        ];
      }
      else operations := list [
        Tezos.transaction(
          Redeem(record [
            user = Tezos.sender;
            amount  = safeRedeemParams.amount;
          ]), 
          0mutez, 
          getUseEntrypoint(safeRedeemParams.qToken)
        )
      ];
    }
    | RedeemMiddle(redeemMiddleParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | BorrowMiddle(borrowMiddleParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | LiquidateMiddle(liquidateMiddleParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function redeemMiddle (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(membershipParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | RedeemMiddle(redeemMiddleParams) -> {
      if Tezos.sender =/= this then
        failwith("NotSelfAddress")
      else skip;

      operations := list [
        Tezos.transaction(
          record [
            user         = redeemMiddleParams.user;
            qToken       = redeemMiddleParams.qToken;
            redeemTokens = redeemMiddleParams.redeemTokens;
            borrowAmount = redeemMiddleParams.borrowAmount;
          ],
          0mutez, 
          getEnsuredRedeemEntrypoint(this)
        )
      ];
    }
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | BorrowMiddle(borrowMiddleParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | LiquidateMiddle(liquidateMiddleParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function ensuredRedeem (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(membershipParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | RedeemMiddle(redeemMiddleParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> {
      if Tezos.sender =/= this then
        failwith("NotSelfAddress")
      else skip;

      const response = getUserLiquidity(ensuredRedeemParams.user, ensuredRedeemParams.qToken, ensuredRedeemParams.redeemTokens, ensuredRedeemParams.borrowAmount, s);
      
      if response.shortfail =/= 0n then
        failwith("ShortfailNotZero")
      else skip;

      operations := list [
        Tezos.transaction(
          Redeem(record [
            user    = ensuredRedeemParams.user;
            amount  = ensuredRedeemParams.redeemTokens;
          ]),
          0mutez,
          getUseEntrypoint(ensuredRedeemParams.qToken)
        )
      ];
    }
    | SafeBorrow(safeBorrowParams) -> skip
    | BorrowMiddle(borrowMiddleParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | LiquidateMiddle(liquidateMiddleParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function safeBorrow (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(membershipParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | RedeemMiddle(redeemMiddleParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> {
      mustContainsQTokens(safeBorrowParams.qToken, s);
      mustContainsQTokens(safeBorrowParams.borrowerToken, s);


      var tokens : membershipParams := getAccountMembership(Tezos.sender, s);

      if tokens.collateralToken = safeBorrowParams.qToken then
        failwith("AlreadyEnteredToMarket")
      else skip;

      tokens.collateralToken := safeBorrowParams.qToken;
      tokens.borrowerToken := safeBorrowParams.borrowerToken;

      s.accountMembership[Tezos.sender] := tokens;

      // borrowAmount = getAccountBorrows(Tezos.sender, safeBorrowParams.qToken, s); ?????????

      operations := list [
        Tezos.transaction(
          QUpdateControllerState(Tezos.sender),
          0mutez, 
          getUpdateControllerStateEntrypoint(safeBorrowParams.borrowerToken)
        );
        Tezos.transaction(
          record [
            user         = Tezos.sender;
            qToken       = safeBorrowParams.borrowerToken;
            redeemTokens = safeBorrowParams.amount;
            borrowAmount = safeBorrowParams.amount;
          ],
          0mutez,
          getBorrowMiddleEntrypoint(this)
        )
      ];
    }
    | BorrowMiddle(borrowMiddleParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | LiquidateMiddle(liquidateMiddleParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function borrowMiddle (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(membershipParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | RedeemMiddle(redeemMiddleParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | BorrowMiddle(borrowMiddleParams) -> {
      if Tezos.sender =/= this then
        failwith("NotSelfAddress")
      else skip;

      operations := list [
        Tezos.transaction(
          record [
            user         = borrowMiddleParams.user;
            qToken       = borrowMiddleParams.qToken;
            redeemTokens = borrowMiddleParams.redeemTokens;
            borrowAmount = borrowMiddleParams.borrowAmount;
          ],
          0mutez, 
          getEnsuredBorrowEntrypoint(this)
        )
      ];
    }
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | LiquidateMiddle(liquidateMiddleParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function ensuredBorrow (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(membershipParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | RedeemMiddle(redeemMiddleParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | BorrowMiddle(borrowMiddleParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> {
      if Tezos.sender =/= this then
        failwith("NotSelfAddress")
      else skip;

      const response = getUserLiquidity(ensuredBorrowParams.user, ensuredBorrowParams.qToken, ensuredBorrowParams.redeemTokens, ensuredBorrowParams.borrowAmount, s);
      
      if response.shortfail =/= 0n then
        failwith("ShortfailNotZero")
      else skip;

      operations := list [
        Tezos.transaction(
          Borrow(record [
            user   = ensuredBorrowParams.user;
            amount = ensuredBorrowParams.borrowAmount;
          ]),
          0mutez,
          getUseEntrypoint(ensuredBorrowParams.qToken)
        )
      ];
    }
    | SafeRepay(safeRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | LiquidateMiddle(liquidateMiddleParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function safeRepay (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(membershipParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | RedeemMiddle(redeemMiddleParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | BorrowMiddle(borrowMiddleParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> {
      mustContainsQTokens(safeRepayParams.qToken, s);

      operations := list [
        Tezos.transaction(
          Repay(record [
            user    = Tezos.sender;
            amount  = safeRepayParams.amount;
          ]),
          0mutez, 
          getUseEntrypoint(safeRepayParams.qToken)
        )
      ];
    }
    | SafeLiquidate(safeLiquidateParams) -> skip
    | LiquidateMiddle(liquidateMiddleParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function safeLiquidate (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(membershipParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | RedeemMiddle(redeemMiddleParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | BorrowMiddle(borrowMiddleParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> {
      mustContainsQTokens(safeLiquidateParams.qToken, s);

      var tokens : membershipParams := getAccountMembership(Tezos.sender, s);

      operations := list [
        Tezos.transaction(
          QUpdateControllerState(Tezos.sender), 
          0mutez, 
          getUpdateControllerStateEntrypoint(tokens.collateralToken)
        )
      ];

      operations := Tezos.transaction(
        record [
            user         = Tezos.sender;
            borrower     = safeLiquidateParams.borrower;
            qToken       = safeLiquidateParams.qToken;
            redeemTokens = safeLiquidateParams.amount;
            borrowAmount = getAccountBorrows(safeLiquidateParams.borrower, safeLiquidateParams.qToken, s);
        ], 
        0mutez, 
        getLiquidateMiddleEntrypoint(this)
      ) # operations;
    }
    | LiquidateMiddle(liquidateMiddleParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function liquidateMiddle (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(membershipParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | RedeemMiddle(redeemMiddleParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | BorrowMiddle(borrowMiddleParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | LiquidateMiddle(liquidateMiddleParams) -> {
      if Tezos.sender =/= this then
        failwith("NotSelfAddress")
      else skip;
      
      operations := list [
        Tezos.transaction(
          record [
              user         = liquidateMiddleParams.user;
              borrower     = liquidateMiddleParams.borrower;
              qToken       = liquidateMiddleParams.qToken;
              redeemTokens = liquidateMiddleParams.redeemTokens;
              borrowAmount = liquidateMiddleParams.borrowAmount;
          ], 
          0mutez,
          getEnsuredLiquidateEntrypoint(this)
        )
      ];
    }
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function ensuredLiquidate (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(updateParams) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(membershipParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | RedeemMiddle(redeemMiddleParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | BorrowMiddle(borrowMiddleParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | LiquidateMiddle(liquidateMiddleParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> {
      if Tezos.sender =/= this then
        failwith("NotSelfAddress")
      else skip;

      const response = getUserLiquidity(ensuredLiquidateParams.user, ensuredLiquidateParams.qToken, ensuredLiquidateParams.redeemTokens, ensuredLiquidateParams.borrowAmount, s);

      if response.shortfail =/= 0n then
        failwith("ShortfailNotZero")
      else skip;

      operations := list [
        Tezos.transaction(
          Liquidate(record [
            liquidator     = ensuredLiquidateParams.user;
            borrower       = ensuredLiquidateParams.borrower;
            amount         = ensuredLiquidateParams.redeemTokens;
          ]), 
          0mutez, 
          getUseEntrypoint(ensuredLiquidateParams.qToken)
        )
      ];
    }
    end
  } with (operations, s)

function main (const p : entryAction; const s : fullControllerStorage) : fullReturn is
  block {
    const this: address = Tezos.self_address;
  } with case p of
      | UseController(params)         -> middleController(params, this, s)
      | SetUseAction(params)          -> setUseAction(params.index, params.func, s)
      | SetFactory(params)            -> setFactory(params, s)
    end
