#include "../partial/IController.ligo"


function getUpdatePriceEntrypoint(const tokenAddress : address) is
  case (
    Tezos.get_entrypoint_opt("%updatePrice", tokenAddress)
                    : option(contract(contrParam))
  ) of
  | None -> (failwith("Callback function not found") : contract(contrParam))
  | Some(p) -> p
  end;

function setFactory(
  const newFactoryAddress: address;
  var s                  : fullControllerStorage)
                         : fullReturn is
  block {
    if (Tezos.sender = s.storage.admin)
    then s.storage.factory := newFactoryAddress;
    else failwith("YouNotAdmin");
  } with (noOperations, s)

function setUseAction(
  const idx             : nat;
  const f               : useControllerFunc;
  var s                 : fullControllerStorage)
                        : fullReturn is
  block {
    if Tezos.sender = s.storage.admin
    then case s.useControllerLambdas[idx] of
        Some(_n) -> failwith("ControllerFunctionSet")
        | None -> s.useControllerLambdas[idx] := f
      end;
    else failwith("YouNotAdmin(ControllerUseAction)")
  } with (noOperations, s)

[@inline] function middleController(
  const p               : useControllerAction;
  const this            : address;
  var s                 : fullControllerStorage)
                        : fullReturn is
  block {
    const idx : nat = case p of
      | UpdatePrice(_contrParam) -> 0n
      | SendToOracle(_addr) -> 1n
      | SetOracle(_setOracleParams) -> 2n
      | Register(_registerParams) -> 3n
      | UpdateQToken(_updateQTokenParams) -> 4n
      | ExitMarket -> 5n
      | EnsuredExitMarket(_ensuredExitMarketParams) -> 6n
      | SafeMint(_safeMintParams) -> 7n
      | SafeRedeem(_safeRedeemParams) -> 8n
      | EnsuredRedeem(_ensuredRedeemParams) -> 9n
      | SafeBorrow(_safeBorrowParams) -> 10n
      | EnsuredBorrow(_ensuredBorrowParams) -> 11n
      | SafeRepay(_safeRepayParams) -> 12n
      | EnsuredRepay(_ensuredRepayParams) -> 13n
      | SafeLiquidate(_safeLiquidateParams) -> 14n
      | EnsuredLiquidate(_ensuredLiquidateParams) -> 15n
    end;

    const res : return = case s.useControllerLambdas[idx] of
      Some(f) -> f(p, this, s.storage)
      | None -> (
        failwith("ControllerFunctionSetInMiddleController") : return
      )
    end;
    s.storage := res.1;
  } with (res.0, s)

[@inline] function mustContainsQTokens(
  const qToken          : address;
  const s               : controllerStorage)
                        : unit is
  block {
    if (s.qTokens contains qToken)
    then skip
    else failwith("qTokenNotContainInSet");
  } with (unit)

[@inline] function mustNotContainsQTokens(
  const qToken          : address;
  const s               : controllerStorage)
                        : unit is
  block {
    if (s.qTokens contains qToken)
    then failwith("qTokenContainInSet")
    else skip;
  } with (unit)

function getUseEntrypoint(
  const tokenAddress    : address)
                        : contract(useParam) is
  case (
    Tezos.get_entrypoint_opt("%use", tokenAddress)
                        : option(contract(useParam))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("CantGetUseEntrypoint") : contract(useParam)
    )
  end;

[@inline] function getNormalizerContract(
  const oracleAddress   : address)
                        : contract(getType) is
  case (
    Tezos.get_entrypoint_opt("%get", oracleAddress)
                        : option(contract(getType))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("CantGetOracleEntrypoint") : contract(getType)
    )
  end;

function getUpdateControllerStateEntrypoint(
  const tokenAddress    : address)
                        : contract(updateControllerStateType) is
  case (
    Tezos.get_entrypoint_opt("%updateControllerState", tokenAddress)
                        : option(contract(updateControllerStateType))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("CantGetUpdateControllerStateEntrypoint")
                        : contract(updateControllerStateType)
    )
  end;

[@inline] function getEnsuredExitMarketEntrypoint(
  const tokenAddress    : address)
                        : contract(ensuredExitMarketParams) is
  case (
    Tezos.get_entrypoint_opt("%ensuredExitMarket", tokenAddress)
                        : option(contract(ensuredExitMarketParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("CantGetEnsuredExitMarketEntrypoint")
                        : contract(ensuredExitMarketParams)
    )
  end;

[@inline] function getEnsuredRedeemEntrypoint(
  const tokenAddress    : address)
                        : contract(ensuredRedeemParams) is
  case (
    Tezos.get_entrypoint_opt("%ensuredRedeem", tokenAddress)
                        : option(contract(ensuredRedeemParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("CantGetEnsuredRedeemEntrypoint")
                        : contract(ensuredRedeemParams)
    )
  end;

[@inline] function getEnsuredBorrowEntrypoint(
  const tokenAddress    : address)
                        : contract(ensuredBorrowParams) is
  case (
    Tezos.get_entrypoint_opt("%ensuredBorrow", tokenAddress)
                        : option(contract(ensuredBorrowParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("CantGetEnsuredBorrowEntrypoint")
                        : contract(ensuredBorrowParams)
    )
  end;

[@inline] function getEnsuredRepayEntrypoint(
  const tokenAddress    : address)
                        : contract(ensuredRepayParams) is
  case (
    Tezos.get_entrypoint_opt("%ensuredRepay", tokenAddress)
                        : option(contract(ensuredRepayParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("CantGetEnsuredRepayEntrypoint")
                        : contract(ensuredRepayParams)
    )
  end;

[@inline] function getEnsuredLiquidateEntrypoint(
  const tokenAddress    : address)
                        : contract(ensuredLiquidateParams) is
  case (
    Tezos.get_entrypoint_opt("%ensuredLiquidate", tokenAddress)
                        : option(contract(ensuredLiquidateParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("CantGetEnsuredLiquidateEntrypoint")
                        : contract(ensuredLiquidateParams)
    )
  end;

[@inline] function getAccountTokens(
  const user            : address;
  const qToken          : address;
  const s               : controllerStorage)
                        : nat is
  case s.accountTokens[(user, qToken)] of
    Some (value) -> value
  | None -> 0n
  end;

function getAccountBorrows(
  const user            : address;
  const qToken          : address;
  const s               : controllerStorage)
                        : nat is
  case s.accountBorrows[(user, qToken)] of
    Some (value) -> value
  | None -> 0n
  end;

[@inline] function checkOraclePair(
  const qToken          : address;
  const s               : controllerStorage)
                        : string is
  case s.oraclePairs[qToken] of
    | Some(v) -> v
    | None -> (failwith("StringNotDefined") : string)
  end;

[@inline] function checkStringOraclePair(
  const pairName        : string;
  const s               : controllerStorage)
                        : address is
  case s.oracleStringPairs[pairName] of
    | Some(v) -> v
    | None -> (failwith("AddressNotDefined") : address)
  end;

function getMarket(
  const qToken          : address;
  const s               : controllerStorage)
                        : market is
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

function getAccountMembership(
  const user            : address;
  const s               : controllerStorage)
                        : membershipParams is
  case s.accountMembership[user] of
    Some (value) -> value
  | None -> (record [
      borrowerToken = ("tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg" : address);
      collateralToken = ("tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg" : address)
    ])
  end;

function getUserLiquidity (
  const user            : address;
  const qToken          : address;
  const redeemTokens    : nat;
  const borrowAmount    : nat;
  const s               : controllerStorage)
                        : getUserLiquidityReturn is
  block {
    var tokens : membershipParams := getAccountMembership(user, s);
    var collateralMarket : market := getMarket(tokens.collateralToken, s);
    var borrowedMarket : market := getMarket(tokens.borrowerToken, s);

    const collateralTokensToDenom : nat = collateralMarket.collateralFactor *
      collateralMarket.exchangeRate * collateralMarket.lastPrice;
    // ?? UNUSED
    // const borrowedTokensToDenom : nat = borrowedMarket.collateralFactor *
    //   borrowedMarket.exchangeRate * borrowedMarket.lastPrice;

    //  calculate collateral based on the collateral market
    var sumCollateral : nat :=  collateralTokensToDenom *
      getAccountTokens(user, tokens.collateralToken, s) / accuracy;
    // calculate borrow based on the borrows market
    var sumBorrow : nat := borrowedMarket.lastPrice *
      getAccountBorrows(user, tokens.borrowerToken, s) / accuracy;

    // calculate the impack of the current operation
    if tokens.collateralToken = qToken
    then block {
      sumBorrow := sumBorrow + collateralTokensToDenom * redeemTokens;
      sumBorrow := sumBorrow + borrowedMarket.lastPrice * borrowAmount;
    } else skip;

    var response : getUserLiquidityReturn :=
    record [
      surplus   = 0n;
      shortfail = 0n;
    ];

    if sumCollateral > sumBorrow
    then response.surplus := abs(sumCollateral - sumBorrow);
    else response.shortfail := abs(sumBorrow - sumCollateral);
  } with (response)

function updatePrice(
  const p               : useControllerAction;
  const _this           : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      UpdatePrice(contrParam) -> {
        if Tezos.sender =/= s.oracle
        then failwith("NotOracle")
        else skip;

        const qToken : address = checkStringOraclePair(contrParam.0, s);

        mustContainsQTokens(qToken, s);

        var m : market := getMarket(qToken, s);

        m.lastPrice := contrParam.1.1;
        s.markets[qToken] := m;
      }
    | _                 -> skip
    end
  } with (operations, s)

function sendToOracle(
  const p               : useControllerAction;
  const this            : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      SendToOracle(addr) -> {
        if Tezos.sender =/= s.admin
        then failwith("NotAdmin")
        else skip;

        const strName : string = checkOraclePair(addr, s);
        var param : contract(contrParam) := getUpdatePriceEntrypoint(this);

        operations := list[
          Tezos.transaction(
            Get(strName, param),
            0mutez,
            getNormalizerContract(s.oracle)
          )
        ];
      }
    | _                 -> skip
    end
  } with (operations, s)

function setOracle(
  const p               : useControllerAction;
  const _this            : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      SetOracle(setOracleParams) -> {
        if Tezos.sender =/= s.admin
        then failwith("NotAdmin")
        else skip;

        s.oracle := setOracleParams;
      }
    | _                 -> skip
    end
  } with (operations, s)

function register(
  const p               : useControllerAction;
  const _this            : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      Register(registerParams) -> {
        if Tezos.sender =/= s.factory
        then failwith("NotFactory")
        else skip;

        mustNotContainsQTokens(registerParams.qToken, s);

        s.qTokens := Set.add(registerParams.qToken, s.qTokens);
        s.pairs[registerParams.token] := registerParams.qToken;

        s.oraclePairs[registerParams.qToken] := registerParams.pairName;
        s.oracleStringPairs[registerParams.pairName] := registerParams.qToken;
      }
    | _                 -> skip
    end
  } with (operations, s)

function updateQToken(
  const p               : useControllerAction;
  const this            : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      UpdateQToken(updateQTokenParams) -> {
        mustContainsQTokens(Tezos.sender, s);

        var m : market := getMarket(Tezos.sender, s);
        m.exchangeRate := updateQTokenParams.exchangeRate;

        s.accountTokens[
          (updateQTokenParams.user, Tezos.sender)
        ] := updateQTokenParams.balance;
        s.accountBorrows[
          (updateQTokenParams.user, Tezos.sender)
        ] := updateQTokenParams.borrow;
        s.markets[this] := m;
      }
    | _                 -> skip
    end
  } with (operations, s)

function exitMarket(
  const p               : useControllerAction;
  const this            : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      ExitMarket -> {
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
    | _                 -> skip
    end
  } with (operations, s)

function ensuredExitMarket(
  const p               : useControllerAction;
  const this            : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      EnsuredExitMarket(ensuredExitMarketParams) -> {
        if Tezos.sender =/= this
        then failwith("NotSelfAddress")
        else skip;

        if ensuredExitMarketParams.borrowerToken = (
          "tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg" : address
        )
        then failwith("NotEnter")
        else skip;

        if getAccountBorrows(
          ensuredExitMarketParams.user, ensuredExitMarketParams.borrowerToken, s
        ) =/= 0n then failwith("BorrowsExists")
        else skip;

        remove ensuredExitMarketParams.user from map s.accountMembership
      }
    | _                 -> skip
    end
  } with (operations, s)

function safeMint(
  const p               : useControllerAction;
  const _this           : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      SafeMint(safeMintParams) -> {
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
    | _                 -> skip
    end
  } with (operations, s)

function safeRedeem(
  const p               : useControllerAction;
  const this            : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      SafeRedeem(safeRedeemParams) -> {
        mustContainsQTokens(safeRedeemParams.qToken, s);

        var tokens : membershipParams := getAccountMembership(Tezos.sender, s);

        if tokens.collateralToken = safeRedeemParams.qToken
        then block {
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
                borrowAmount = getAccountBorrows(
                  Tezos.sender, safeRedeemParams.qToken, s
                );
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
    | _                 -> skip
    end
  } with (operations, s)

function ensuredRedeem(
  const p               : useControllerAction;
  const this            : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      EnsuredRedeem(ensuredRedeemParams) -> {
        if Tezos.sender =/= this
        then failwith("NotSelfAddress")
        else skip;

        const response = getUserLiquidity(
          ensuredRedeemParams.user,
          ensuredRedeemParams.qToken,
          ensuredRedeemParams.redeemTokens,
          ensuredRedeemParams.borrowAmount,
          s
        );

        s.icontroller := response.shortfail;

        if response.shortfail =/= 0n
        then failwith("ShortfailNotZero")
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
    | _                 -> skip
    end
  } with (operations, s)

function safeBorrow(
  const p               : useControllerAction;
  const this            : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      SafeBorrow(safeBorrowParams) -> {
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
    | _                 -> skip
    end
  } with (operations, s)

function ensuredBorrow(
  const p               : useControllerAction;
  const this            : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      EnsuredBorrow(ensuredBorrowParams) -> {
        if Tezos.sender =/= this
        then failwith("NotSelfAddress")
        else skip;

        const response = getUserLiquidity(
          ensuredBorrowParams.user,
          ensuredBorrowParams.qToken,
          ensuredBorrowParams.redeemTokens,
          ensuredBorrowParams.borrowAmount,
          s
        );

        s.icontroller := response.shortfail;

        if response.shortfail =/= 0n
        then failwith("ShortfailNotZero")
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
    | _                 -> skip
    end
  } with (operations, s)

function safeRepay(
  const p               : useControllerAction;
  const this            : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      SafeRepay(safeRepayParams) -> {
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
    | _                 -> skip
    end
  } with (operations, s)

function ensuredRepay(
  const p               : useControllerAction;
  const this            : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      EnsuredRepay(ensuredRepayParams) -> {
        if Tezos.sender =/= this
        then failwith("NotSelfAddress")
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
    | _                 -> skip
    end
  } with (operations, s)

function safeLiquidate(
  const p               : useControllerAction;
  const this            : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      SafeLiquidate(safeLiquidateParams) -> {
        mustContainsQTokens(safeLiquidateParams.qToken, s);

        var tokens : membershipParams := getAccountMembership(Tezos.sender, s);
        var tokensBorrow : membershipParams := getAccountMembership(
          safeLiquidateParams.borrower,
          s
        );

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
                borrowAmount    = getAccountBorrows(
                  safeLiquidateParams.borrower,
                  safeLiquidateParams.qToken,
                  s
                );
                collateralToken = tokensBorrow.collateralToken;
            ],
            0mutez,
            getEnsuredLiquidateEntrypoint(this)
          )
        ];
      }
    | _                 -> skip
    end
  } with (operations, s)

function ensuredLiquidate(
  const p               : useControllerAction;
  const this            : address;
  var s                 : controllerStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
    case p of
      EnsuredLiquidate(ensuredLiquidateParams) -> {
        if Tezos.sender =/= this
        then failwith("NotSelfAddress")
        else skip;

        const response = getUserLiquidity(
          ensuredLiquidateParams.user,
          ensuredLiquidateParams.qToken,
          ensuredLiquidateParams.redeemTokens,
          ensuredLiquidateParams.borrowAmount,
          s
        );

        if response.shortfail =/= 0n
        then failwith("ShortfailNotZero")
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
    | _                 -> skip
    end
  } with (operations, s)

function main(
  const p               : entryAction;
  const s               : fullControllerStorage)
                        : fullReturn is
  block {
    const this: address = Tezos.self_address;
  } with case p of
      | UseController(params)         -> middleController(params, this, s)
      | SetUseAction(params)          -> setUseAction(
                                          params.index,
                                          params.func,
                                          s)
      | SetFactory(params)            -> setFactory(params, s)
    end
