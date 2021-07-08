#include "../partials/IController.ligo"

function setFactory (const newFactoryAddress: address; const s : fullControllerStorage) : fullReturn is
  block {
    if (Tezos.sender = s.storage.admin) then
      s.storage.factory := newFactoryAddress;
    else failwith("YouNotAdmin");
  } with (noOperations, s)

function setUseAction (const idx : nat; const f : useControllerFunc; const s : fullControllerStorage) : fullReturn is
  block {
    if Tezos.sender = s.storage.admin then
      case s.useControllerLambdas[idx] of
        Some(n) -> failwith("ControllerFunctionSet")
        | None -> s.useControllerLambdas[idx] := f
      end;
    else failwith("YouNotAdmin(ControllerUseAction)")
  } with (noOperations, s)

[@inline] function middleController (const p : useControllerAction; const this : address; const s : fullControllerStorage) : fullReturn is
  block {
    const idx : nat = case p of
      | UpdatePrice(contrParam) -> 0n
      | SendToOracle(addr) -> 1n
      | SetOracle(setOracleParams) -> 2n
      | Register(registerParams) -> 3n
      | UpdateQToken(updateQTokenParams) -> 4n
      | ExitMarket(addr) -> 5n
      | EnsuredExitMarket(ensuredExitMarketParams) -> 6n
      | SafeMint(safeMintParams) -> 7n
      | SafeRedeem(safeRedeemParams) -> 8n
      | EnsuredRedeem(ensuredRedeemParams) -> 9n
      | SafeBorrow(safeBorrowParams) -> 10n
      | EnsuredBorrow(ensuredBorrowParams) -> 11n
      | SafeRepay(safeRepayParams) -> 12n
      | EnsuredRepay(ensuredRepayParams) -> 13n
      | SafeLiquidate(safeLiquidateParams) -> 14n
      | EnsuredLiquidate(ensuredLiquidateParams) -> 15n
    end;

    const res : return = case s.useControllerLambdas[idx] of
      Some(f) -> f(p, this, s.storage)
      | None -> (failwith("ControllerFunctionSetInMiddleController") : return)
    end;
    s.storage := res.1;
  } with (res.0, s)

[@inline] function mustContainsQTokens (const qToken : address; const s : controllerStorage) : unit is
  block {
    if (s.qTokens contains qToken) then skip
    else failwith("qTokenNotContainInSet");
  } with (unit)

[@inline] function mustNotContainsQTokens (const qToken : address; const s : controllerStorage) : unit is
  block {
    if (s.qTokens contains qToken) then
      failwith("qTokenContainInSet")
    else skip;
  } with (unit)

[@inline] function getUseEntrypoint (const tokenAddress : address) : contract(useParam) is
  case (Tezos.get_entrypoint_opt("%use", tokenAddress) : option(contract(useParam))) of
    Some(contr) -> contr
    | None -> (failwith("CantGetUseEntrypoint") : contract(useParam))
  end;

[@inline] function getNormalizerContract (const oracleAddress : address) : contract(getType) is
  case (Tezos.get_entrypoint_opt("%get", oracleAddress) : option(contract(getType))) of
    Some(contr) -> contr
    | None -> (failwith("CantGetOracleEntrypoint") : contract(getType))
  end;

[@inline] function getUpdateControllerStateEntrypoint (const tokenAddress : address) : contract(updateControllerStateType) is
  case (Tezos.get_entrypoint_opt("%updateControllerState", tokenAddress) : option(contract(updateControllerStateType))) of
    Some(contr) -> contr
    | None -> (failwith("CantGetUpdateControllerStateEntrypoint") : contract(updateControllerStateType))
  end;

[@inline] function getEnsuredExitMarketEntrypoint (const tokenAddress : address) : contract(ensuredExitMarketParams) is
  case (Tezos.get_entrypoint_opt("%ensuredExitMarket", tokenAddress) : option(contract(ensuredExitMarketParams))) of
    Some(contr) -> contr
    | None -> (failwith("CantGetEnsuredExitMarketEntrypoint") : contract(ensuredExitMarketParams))
  end;

[@inline] function getEnsuredRedeemEntrypoint (const tokenAddress : address) : contract(ensuredRedeemParams) is
  case (Tezos.get_entrypoint_opt("%ensuredRedeem", tokenAddress) : option(contract(ensuredRedeemParams))) of
    Some(contr) -> contr
    | None -> (failwith("CantGetEnsuredRedeemEntrypoint") : contract(ensuredRedeemParams))
  end;

[@inline] function getEnsuredBorrowEntrypoint (const tokenAddress : address) : contract(ensuredBorrowParams) is
  case (Tezos.get_entrypoint_opt("%ensuredBorrow", tokenAddress) : option(contract(ensuredBorrowParams))) of
    Some(contr) -> contr
    | None -> (failwith("CantGetEnsuredBorrowEntrypoint") : contract(ensuredBorrowParams))
  end;

[@inline] function getEnsuredRepayEntrypoint (const tokenAddress : address) : contract(ensuredRepayParams) is
  case (Tezos.get_entrypoint_opt("%ensuredRepay", tokenAddress) : option(contract(ensuredRepayParams))) of
    Some(contr) -> contr
    | None -> (failwith("CantGetEnsuredRepayEntrypoint") : contract(ensuredRepayParams))
  end;

[@inline] function getEnsuredLiquidateEntrypoint (const tokenAddress : address) : contract(ensuredLiquidateParams) is
  case (Tezos.get_entrypoint_opt("%ensuredLiquidate", tokenAddress) : option(contract(ensuredLiquidateParams))) of
    Some(contr) -> contr
    | None -> (failwith("CantGetEnsuredLiquidateEntrypoint") : contract(ensuredLiquidateParams))
  end;

[@inline] function getAccountTokens (const user : address; const qToken : address; const s : controllerStorage) : nat is
  case s.accountTokens[(user, qToken)] of
    Some (value) -> value
  | None -> 0n
  end;

[@inline] function getAccountBorrows (const user : address; const qToken : address; const s : controllerStorage ) : nat is
  case s.accountBorrows[(user, qToken)] of
    Some (value) -> value
  | None -> 0n
  end;

[@inline] function checkOraclePair (const qToken : address; const s : controllerStorage) : string is
  case s.oraclePairs[qToken] of
    | Some(v) -> v
    | None -> (failwith("StringNotDefined") : string)
  end;

[@inline] function checkStringOraclePair (const pairName : string; const s : controllerStorage) : address is
  case s.oracleStringPairs[pairName] of
    | Some(v) -> v
    | None -> (failwith("AddressNotDefined") : address)
  end;

[@inline] function getMarket (const qToken : address; const s : controllerStorage) : market is
  block {
    var m : market := record [
      collateralFactor = 0n;
      lastPrice        = 0n;
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

function getUserLiquidity (const user : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : controllerStorage) : getUserLiquidityReturn is
  block {
    var tokens : membershipParams := getAccountMembership(user, s);
    var collateralMarket : market := getMarket(tokens.collateralToken, s);
    var borrowedMarket : market := getMarket(tokens.borrowerToken, s);

    const collateralTokensToDenom : nat = collateralMarket.collateralFactor * collateralMarket.exchangeRate * collateralMarket.lastPrice;
    const borrowedTokensToDenom : nat = borrowedMarket.collateralFactor * borrowedMarket.exchangeRate * borrowedMarket.lastPrice;

    //  calculate collateral based on the collateral market
    var sumCollateral : nat :=  collateralTokensToDenom * getAccountTokens(user, tokens.collateralToken, s) / accuracy;
    // calculate borrow based on the borrows market
    var sumBorrow : nat := borrowedMarket.lastPrice * getAccountBorrows(user, tokens.borrowerToken, s) / accuracy;

    // calculate the impack of the current operation
    if tokens.collateralToken = qToken then block {
      sumBorrow := sumBorrow + collateralTokensToDenom * redeemTokens;
      sumBorrow := sumBorrow + borrowedMarket.lastPrice * borrowAmount;
    } else skip;

    var response : getUserLiquidityReturn :=
    record [
      surplus   = 0n;
      shortfail = 0n;
    ];

    if sumCollateral > sumBorrow then
      response.surplus := abs(sumCollateral - sumBorrow);
    else response.shortfail := abs(sumBorrow - sumCollateral);
  } with (response)

function updatePrice (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(contrParam) -> {
      if Tezos.sender =/= s.oracle then
        failwith("NotOracle")
      else skip;

      const qToken : address = checkStringOraclePair(contrParam.0, s);

      mustContainsQTokens(qToken, s);

      var m : market := getMarket(qToken, s);

      m.lastPrice := contrParam.1.1;
      s.markets[qToken] := m;
    }
    | SendToOracle(addr) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(addr) -> skip
    | EnsuredExitMarket(ensuredExitMarketParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | EnsuredRepay(ensuredRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function sendToOracle (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(contrParam) -> skip
    | SendToOracle(addr) -> {
      if Tezos.sender =/= s.admin then
          failwith("NotAdmin")
      else skip;

      const strName : string = checkOraclePair(addr, s);
      var param : contract(contrParam) := nil;

      case (Tezos.get_entrypoint_opt("%updatePrice", this) : option(contract(contrParam))) of
      | None -> failwith("Callback function not found")
      | Some(p) -> param := p
      end;

      operations := list[
        Tezos.transaction(
          Get(strName, param),
          0mutez,
          getNormalizerContract(s.oracle)
        )
      ];
    }
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(addr) -> skip
    | EnsuredExitMarket(ensuredExitMarketParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | EnsuredRepay(ensuredRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function setOracle (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(contrParam) -> skip
    | SendToOracle(addr) -> skip
    | SetOracle(setOracleParams) -> {
      if Tezos.sender =/= s.admin then
        failwith("NotAdmin")
      else skip;

      s.oracle := setOracleParams;
    }
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(addr) -> skip
    | EnsuredExitMarket(ensuredExitMarketParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | EnsuredRepay(ensuredRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function register (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(contrParam) -> skip
    | SendToOracle(addr) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> {
      if Tezos.sender =/= s.factory then
        failwith("NotFactory")
      else skip;

      mustNotContainsQTokens(registerParams.qToken, s);

      s.qTokens := Set.add(registerParams.qToken, s.qTokens);
      s.pairs[registerParams.token] := registerParams.qToken;

      s.oraclePairs[registerParams.qToken] := registerParams.pairName;
      s.oracleStringPairs[registerParams.pairName] := registerParams.qToken;
    }
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(addr) -> skip
    | EnsuredExitMarket(ensuredExitMarketParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | EnsuredRepay(ensuredRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function updateQToken (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(contrParam) -> skip
    | SendToOracle(addr) -> skip
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
    | ExitMarket(addr) -> skip
    | EnsuredExitMarket(ensuredExitMarketParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | EnsuredRepay(ensuredRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function exitMarket (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(contrParam) -> skip
    | SendToOracle(addr) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(addr) -> {
      var tokens : membershipParams := getAccountMembership(Tezos.sender, s);

      operations := list [
        Tezos.transaction(
          QUpdateControllerState(Tezos.sender),
          0mutez,
          getUpdateControllerStateEntrypoint(tokens.collateralToken)
        );
        Tezos.transaction(
          QUpdateControllerState(Tezos.sender),
          0mutez,
          getUpdateControllerStateEntrypoint(tokens.borrowerToken)
        );
        Tezos.transaction(
          record [
            user            = Tezos.sender;
            borrowerToken   = tokens.borrowerToken;
            collateralToken = tokens.collateralToken;
          ],
          0mutez,
          getEnsuredExitMarketEntrypoint(this)
        )
      ];
    }
    | EnsuredExitMarket(ensuredExitMarketParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | EnsuredRepay(ensuredRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function ensuredExitMarket (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(contrParam) -> skip
    | SendToOracle(addr) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(addr) -> skip
    | EnsuredExitMarket(ensuredExitMarketParams) -> {
      if Tezos.sender =/= this then
        failwith("NotSelfAddress")
      else skip;

      if ensuredExitMarketParams.borrowerToken = ("tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg" : address) then
        failwith("NotEnter")
      else skip;

      if getAccountBorrows(ensuredExitMarketParams.user, ensuredExitMarketParams.borrowerToken, s) =/= 0n then
        failwith("BorrowsExists")
      else skip;

      remove ensuredExitMarketParams.user from map s.accountMembership
    }
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | EnsuredRepay(ensuredRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function safeMint (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(contrParam) -> skip
    | SendToOracle(addr) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(addr) -> skip
    | EnsuredExitMarket(ensuredExitMarketParams) -> skip
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
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | EnsuredRepay(ensuredRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function safeRedeem (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(contrParam) -> skip
    | SendToOracle(addr) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(addr) -> skip
    | EnsuredExitMarket(ensuredExitMarketParams) -> skip
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
            QUpdateControllerState(Tezos.sender),
            0mutez,
            getUpdateControllerStateEntrypoint(tokens.borrowerToken)
          );
          Tezos.transaction(
            record [
              user         = Tezos.sender;
              qToken       = safeRedeemParams.qToken;
              redeemTokens = safeRedeemParams.amount;
              borrowAmount = getAccountBorrows(Tezos.sender, safeRedeemParams.qToken, s);
            ],
            0mutez,
            getEnsuredRedeemEntrypoint(this)
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
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | EnsuredRepay(ensuredRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function ensuredRedeem (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(contrParam) -> skip
    | SendToOracle(addr) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(addr) -> skip
    | EnsuredExitMarket(ensuredExitMarketParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> {
      if Tezos.sender =/= this then
        failwith("NotSelfAddress")
      else skip;

      const response = getUserLiquidity(ensuredRedeemParams.user, ensuredRedeemParams.qToken, ensuredRedeemParams.redeemTokens, ensuredRedeemParams.borrowAmount, s);

      s.icontroller := response.shortfail;

      // if response.shortfail =/= 0n then
      //   failwith("ShortfailNotZero")
      // else skip;

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
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | EnsuredRepay(ensuredRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function safeBorrow (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(contrParam) -> skip
    | SendToOracle(addr) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(addr) -> skip
    | EnsuredExitMarket(ensuredExitMarketParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> {
      mustContainsQTokens(safeBorrowParams.qToken, s);
      mustContainsQTokens(safeBorrowParams.borrowerToken, s);

      var tokens : membershipParams := getAccountMembership(Tezos.sender, s);

      if tokens.collateralToken = safeBorrowParams.qToken then
        failwith("AlreadyEnteredToMarket")
      else skip;

      if safeBorrowParams.qToken = safeBorrowParams.borrowerToken then
        failwith("SimularCollateralAndBorrowerToken")
      else skip;

      tokens.collateralToken := safeBorrowParams.qToken;
      tokens.borrowerToken := safeBorrowParams.borrowerToken;

      s.accountMembership[Tezos.sender] := tokens;

      operations := list [
        Tezos.transaction(
          QUpdateControllerState(Tezos.sender),
          0mutez,
          getUpdateControllerStateEntrypoint(tokens.collateralToken)
        );
        Tezos.transaction(
          QUpdateControllerState(Tezos.sender),
          0mutez,
          getUpdateControllerStateEntrypoint(tokens.borrowerToken)
        );
        Tezos.transaction(
          record [
            user         = Tezos.sender;
            qToken       = safeBorrowParams.borrowerToken;
            redeemTokens = 0n;
            borrowAmount = safeBorrowParams.amount;
          ],
          0mutez,
          getEnsuredBorrowEntrypoint(this)
        )
      ];
    }
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | EnsuredRepay(ensuredRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function ensuredBorrow (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(contrParam) -> skip
    | SendToOracle(addr) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(addr) -> skip
    | EnsuredExitMarket(ensuredExitMarketParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> {
      if Tezos.sender =/= this then
        failwith("NotSelfAddress")
      else skip;

      const response = getUserLiquidity(ensuredBorrowParams.user, ensuredBorrowParams.qToken, ensuredBorrowParams.redeemTokens, ensuredBorrowParams.borrowAmount, s);

      s.icontroller := response.shortfail;

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
    | EnsuredRepay(ensuredRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function safeRepay (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(contrParam) -> skip
    | SendToOracle(addr) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(addr) -> skip
    | EnsuredExitMarket(ensuredExitMarketParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> {
      mustContainsQTokens(safeRepayParams.qToken, s);
      var tokens : membershipParams := getAccountMembership(Tezos.sender, s);

      operations := list [
        Tezos.transaction(
          QUpdateControllerState(Tezos.sender),
          0mutez,
          getUpdateControllerStateEntrypoint(tokens.collateralToken)
        );
        Tezos.transaction(
          QUpdateControllerState(Tezos.sender),
          0mutez,
          getUpdateControllerStateEntrypoint(tokens.borrowerToken)
        );
        Tezos.transaction(
          record [
            user    = Tezos.sender;
            qToken  = safeRepayParams.qToken;
            amount  = safeRepayParams.amount;
          ],
          0mutez,
          getEnsuredRepayEntrypoint(this)
        )
      ];
    }
    | EnsuredRepay(ensuredRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function ensuredRepay (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(contrParam) -> skip
    | SendToOracle(addr) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(addr) -> skip
    | EnsuredExitMarket(ensuredExitMarketParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | EnsuredRepay(ensuredRepayParams) -> {
      if Tezos.sender =/= this then
        failwith("NotSelfAddress")
      else skip;

      operations := list [
        Tezos.transaction(
          Repay(record [
            user    = ensuredRepayParams.user;
            amount  = ensuredRepayParams.amount;
          ]),
          0mutez,
          getUseEntrypoint(ensuredRepayParams.qToken)
        )
      ];
    }
    | SafeLiquidate(safeLiquidateParams) -> skip
    | EnsuredLiquidate(ensuredLiquidateParams) -> skip
    end
  } with (operations, s)

function safeLiquidate (const p : useControllerAction; const this : address; var s : controllerStorage) : return is
  block {
    var operations : list(operation) := list[];
    case p of
    | UpdatePrice(contrParam) -> skip
    | SendToOracle(addr) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(addr) -> skip
    | EnsuredExitMarket(ensuredExitMarketParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | EnsuredRepay(ensuredRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> {
      mustContainsQTokens(safeLiquidateParams.qToken, s);

      var tokens : membershipParams := getAccountMembership(Tezos.sender, s);
      var tokensBorrow : membershipParams := getAccountMembership(safeLiquidateParams.borrower, s);

      operations := list [
        Tezos.transaction(
          QUpdateControllerState(Tezos.sender),
          0mutez,
          getUpdateControllerStateEntrypoint(tokens.collateralToken)
        );
        Tezos.transaction(
          QUpdateControllerState(Tezos.sender),
          0mutez,
          getUpdateControllerStateEntrypoint(tokens.borrowerToken)
        );
        Tezos.transaction(
          record [
              user            = Tezos.sender;
              borrower        = safeLiquidateParams.borrower;
              qToken          = safeLiquidateParams.qToken;
              redeemTokens    = safeLiquidateParams.amount;
              borrowAmount    = getAccountBorrows(safeLiquidateParams.borrower, safeLiquidateParams.qToken, s);
              collateralToken = tokensBorrow.collateralToken;
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
    | UpdatePrice(contrParam) -> skip
    | SendToOracle(addr) -> skip
    | SetOracle(setOracleParams) -> skip
    | Register(registerParams) -> skip
    | UpdateQToken(updateQTokenParams) -> skip
    | ExitMarket(addr) -> skip
    | EnsuredExitMarket(ensuredExitMarketParams) -> skip
    | SafeMint(safeMintParams) -> skip
    | SafeRedeem(safeRedeemParams) -> skip
    | EnsuredRedeem(ensuredRedeemParams) -> skip
    | SafeBorrow(safeBorrowParams) -> skip
    | EnsuredBorrow(ensuredBorrowParams) -> skip
    | SafeRepay(safeRepayParams) -> skip
    | EnsuredRepay(ensuredRepayParams) -> skip
    | SafeLiquidate(safeLiquidateParams) -> skip
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
            liquidator      = ensuredLiquidateParams.user;
            borrower        = ensuredLiquidateParams.borrower;
            amount          = ensuredLiquidateParams.redeemTokens;
            collateralToken = ensuredLiquidateParams.collateralToken;
          ]),
          0mutez,
          getUseEntrypoint(ensuredLiquidateParams.qToken)
        );
        Tezos.transaction(
          Seize(record [
            liquidator  = ensuredLiquidateParams.user;
            borrower    = ensuredLiquidateParams.borrower;
            amount      = ensuredLiquidateParams.redeemTokens;
          ]),
          0mutez,
          getUseEntrypoint(ensuredLiquidateParams.collateralToken)
        );
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
