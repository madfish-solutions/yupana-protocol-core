const zeroAddress : address = ("tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg" : address);
const sumCollateral : nat = 0n;
const sumBorrow : nat = 0n;

type getUserLiquidityReturn is
  record [
    surplus   :nat;
    shortfail :nat;
  ]

type marketInfo is
  record [
    collateralFactor  :nat;
    lastPrice         :nat;
    oracle            :address;
    exchangeRate      :nat;
  ]

type storage is
  record [
    factory           :address;
    admin             :address;
    qTokens           :set(address);
    pairs             :big_map(address, address); // underlying token -> qToken
    accountBorrows    :big_map(michelson_pair(address, "user", address, "token"), nat);
    accountTokens     :big_map(michelson_pair(address, "user", address, "token"), nat);
    markets           :big_map(address, marketInfo); // qToken -> info
    accountMembership :big_map(address, set(address)); // user -> qTokens
  ]
//all numbers in storage are real numbers
const accuracy : nat = 1000000000000000000n; //1e+18

type return is list (operation) * storage
[@inline] const noOperations : list (operation) = nil;

type updateControllerState_type is UpdateControllerState of address
type liquidateMiddle_type is LiquidateMiddle of michelson_pair(address, "liquidator", michelson_pair(michelson_pair(address, "borrower", address, "qToken"), "", 
                                                                                                     michelson_pair(nat, "redeemTokens", nat, "borrowAmount"), ""), "")
type ensuredLiquidate_type is EnsuredLiquidate of michelson_pair(address, "liquidator", michelson_pair(michelson_pair(address, "borrower", address, "qToken"), "", 
                                                                                                       michelson_pair(nat, "redeemTokens", nat, "borrowAmount"), ""), "")
type liquidate_type is Liquidate of michelson_pair(address, "liquidator", michelson_pair(address, "borrower", nat, "amount"), "")

type mintType is record [
  user           :address;
  amt            :nat;
]

type mintParams is record [
  amt            :nat;
  qToken         :address;
]

type redeemType is record [
  user           :address;
  amt            :nat;
]

type redeemParams is record [
  amt            :nat;
  qToken         :address;
]

type redeemMiddleType is record [
    user         :address;
    qToken       :address;
    redeemTokens :nat;
    borrowAmount :nat;
]

type ensuredRedeemType is record [
    user         :address;
    qToken       :address;
    redeemTokens :nat;
    borrowAmount :nat;
]

type borrowType is record [
  user           :address;
  amt            :nat;
]

type borrowParams is record [
  amt            :nat;
  qToken         :address;
]

type borrowMiddleType is record [
  user         :address;
  qToken       :address;
  redeemTokens :nat;
  borrowAmount :nat;
]

type ensuredBorrowType is record [
  user         :address;
  qToken       :address;
  redeemTokens :nat;
  borrowAmount :nat;
]

type repayType is record [
  user           :address;
  amt            :nat;
]

type repayParams is record [
  amt            :nat;
  qToken         :address;
]

type ensureExitMarketType is record [
   user         :address;
   qToken       :address;
   tokens       :set(address);
]

//todo do some actions missing???
type entryAction is
  | UpdatePrice of michelson_pair(address, "qToken", nat, "price")
  | SetOracle of michelson_pair(address, "qToken", address, "oracle")
  | Register of michelson_pair(address, "token", address, "qToken")
  | UpdateQToken of michelson_pair(michelson_pair(address, "user", nat, "balance"), "", michelson_pair(nat, "borrow", nat, "exchangeRate"), "")
  | EnterMarket of address
  | ExitMarket of address
  | EnsureExitMarket of ensureExitMarketType
  | SafeMint of mintParams
  | SafeRedeem of redeemParams
  | RedeemMiddle of redeemMiddleType
  | EnsuredRedeem of ensuredRedeemType
  | SafeBorrow of borrowParams
  | BorrowMiddle of borrowMiddleType
  | EnsuredBorrow of ensuredBorrowType
  | SafeRepay of repayParams
  // | SafeLiquidate of michelson_pair(michelson_pair(address, "borrower", nat, "amount"), "", address, "qToken")
  // | LiquidateMiddleAction of liquidateMiddle_type
  // | EnsuredLiquidateAction of ensuredLiquidate_type

function getAccountTokens(const user : address; const qToken : address; const s : storage) : nat is
  case s.accountTokens[(user, qToken)] of
    Some (value) -> value
  | None -> 0n
  end;

function getAccountBorrows(const user : address; const qToken : address; const s : storage) : nat is
  case s.accountBorrows[(user, qToken)] of
    Some (value) -> value
  | None -> 0n
  end;

function getMarket(const qToken : address; const s : storage) : marketInfo is
  block {
    var m : marketInfo :=
      record [
        collateralFactor = 0n;
        lastPrice        = 0n;
        oracle           = zeroAddress;
        exchangeRate     = 0n;
      ];
    case s.markets[qToken] of
      None -> skip
    | Some(value) -> m := value
    end;
  } with m

function getAccountMembership(const user : address; const s : storage) : set(address) is
  case s.accountMembership[user] of
    Some (value) -> value
  | None -> (set [] : set(address))
  end;

function getMintEntrypoint(const token_address : address) : contract(mintType) is
  case (Tezos.get_entrypoint_opt("%mint", token_address) : option(contract(mintType))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetMintEntrypoint") : contract(mintType))
  end;

function getUpdateControllerStateEntrypoint(const token_address : address) : contract(updateControllerState_type) is
  case (Tezos.get_entrypoint_opt("%updateControllerState", token_address) : option(contract(updateControllerState_type))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetUpdateControllerStateEntrypoint") : contract(updateControllerState_type))
  end;

function getRedeemMiddleEntrypoint(const token_address : address) : contract(redeemMiddleType) is
  case (Tezos.get_entrypoint_opt("%redeemMiddle", token_address) : option(contract(redeemMiddleType))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetRedeemMiddleEntrypoint") : contract(redeemMiddleType))
  end;

function getRedeemEntrypoint(const token_address : address) : contract(redeemType) is
  case (Tezos.get_entrypoint_opt("%redeem", token_address) : option(contract(redeemType))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetRedeemEntrypoint") : contract(redeemType))
  end;

function getEnsuredRedeemEntrypoint(const token_address : address) : contract(ensuredRedeemType) is
  case (Tezos.get_entrypoint_opt("%ensuredRedeem", token_address) : option(contract(ensuredRedeemType))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetEnsuredRedeemEntrypoint") : contract(ensuredRedeemType))
  end;

function getBorrowEntrypoint(const token_address : address) : contract(borrowType) is
  case (Tezos.get_entrypoint_opt("%borrow", token_address) : option(contract(borrowType))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetBorrowEntrypoint") : contract(borrowType))
  end;

function getBorrowMiddleEntrypoint(const token_address : address) : contract(borrowMiddleType) is
  case (Tezos.get_entrypoint_opt("%borrowMiddle", token_address) : option(contract(borrowMiddleType))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetBorrowMiddleEntrypoint") : contract(borrowMiddleType))
  end;

function getEnsuredBorrowEntrypoint(const token_address : address) : contract(ensuredBorrowType) is
  case (Tezos.get_entrypoint_opt("%ensuredBorrow", token_address) : option(contract(ensuredBorrowType))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetEnsuredBorrowEntrypoint") : contract(ensuredBorrowType))
  end;

function getRepayEntrypoint(const token_address : address) : contract(repayType) is
  case (Tezos.get_entrypoint_opt("%repay", token_address) : option(contract(repayType))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetRepayEntrypoint") : contract(repayType))
  end;

function getLiquidateMiddleEntrypoint(const token_address : address) : contract(liquidateMiddle_type) is
  case (Tezos.get_entrypoint_opt("%liquidateMiddle", token_address) : option(contract(liquidateMiddle_type))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetLiquidateMiddleEntrypoint") : contract(liquidateMiddle_type))
  end;

function getEnsuredLiquidateEntrypoint(const token_address : address) : contract(ensuredLiquidate_type) is
  case (Tezos.get_entrypoint_opt("%ensuredLiquidate", token_address) : option(contract(ensuredLiquidate_type))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetEnsuredLiquidateEntrypoint") : contract(ensuredLiquidate_type))
  end;

function getLiquidateEntrypoint(const token_address : address) : contract(liquidate_type) is
  case (Tezos.get_entrypoint_opt("%liquidate", token_address) : option(contract(liquidate_type))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetLiquidateEntrypoint") : contract(liquidate_type))
  end;

function getEnsureExitMarketEntrypoint(const token_address : address) : contract(ensureExitMarketType) is
  case (Tezos.get_entrypoint_opt("%ensureExitMarket", token_address) : option(contract(ensureExitMarketType))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetEnsureExitMarketEntrypoint") : contract(ensureExitMarketType))
  end;

function getUserLiquidity(const user : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : storage) : getUserLiquidityReturn is
  block {
    sumCollateral := 0n;
    sumBorrow := 0n;
    const tokens : set(address) = getAccountMembership(user, s);
    var tokensToDenom : nat := 0n;
    var m : marketInfo := getMarket(qToken, s);


    for token in set tokens block {
      m := getMarket(token, s);
      tokensToDenom := m.collateralFactor * m.exchangeRate * m.lastPrice / accuracy / accuracy;
      sumCollateral := sumCollateral + tokensToDenom * getAccountTokens(user, token, s) / accuracy;
      sumBorrow := sumBorrow + m.lastPrice * getAccountBorrows(user, token, s) / accuracy;
      if token = qToken then block {
        sumBorrow := sumBorrow + tokensToDenom * redeemTokens;
        sumBorrow := sumBorrow + m.lastPrice * borrowAmount;
      }
      else skip;
    };

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

// check that input address contains in storage.qTokens
// will throw an exception if NOT contains
function mustContainsQTokens(const qToken : address; const s : storage) : unit is
  block {
    if (s.qTokens contains qToken) then skip
    else failwith("NotContains");
  } with (unit)

// check that input address NOT contains in storage.qTokens
// will throw an exception if contains
[@inline] function mustNotContainsQTokens(const qToken : address; const s : storage) : unit is
  block {
    if (s.qTokens contains qToken) then
      failwith("Contains")
    else skip;
  } with (unit)

function updatePrice(const qToken : address; const price : nat; var s : storage) : return is
  block {
    mustContainsQTokens(qToken, s);
    var market : marketInfo := getMarket(qToken, s);

    if Tezos.sender =/= market.oracle then
      failwith("NorOracle")
    else skip;

    market.lastPrice := price;
    s.markets[qToken] := market;
  } with (noOperations, s)

function setOracle(const qToken : address; const oracle : address; var s : storage) : return is
  block {
    if Tezos.sender =/= s.admin then
      failwith("NotAdmin")
    else skip;

    var market : marketInfo := getMarket(qToken, s);
    market.oracle := oracle;
    s.markets[qToken] := market;
  } with (noOperations, s)

function register(const token : address; const qToken : address; var s : storage) : return is
  block {
    if Tezos.sender =/= s.factory then
      failwith("NotFactory")
    else skip;

    mustNotContainsQTokens(qToken, s);

    s.qTokens := Set.add(qToken, s.qTokens);
    s.pairs[token] := qToken;
  } with (noOperations, s)

function updateQToken(const user : address; const balance_ : nat; const borrow : nat; const exchangeRate : nat; var s : storage) : return is
  block {
    mustContainsQTokens(Tezos.sender, s);

    var market : marketInfo := getMarket(Tezos.sender, s);
    market.exchangeRate := exchangeRate;

    s.accountTokens[(user, Tezos.sender)] := balance_;
    s.accountBorrows[(user, Tezos.sender)] := borrow;
    s.markets[Tezos.sender] := market;
  } with (noOperations, s)

function enterMarket(const qToken : address; var s : storage) : return is
  block {
    mustContainsQTokens(qToken, s);

    var tokens : set(address) := getAccountMembership(Tezos.sender, s);

    if tokens contains qToken then
      failwith("AlreadyEnter")
    else skip;

    if Set.size(tokens) >= 4n then
      failwith("LimitExceeded")
    else skip;

    tokens := Set.add(qToken, tokens);

    s.accountMembership[Tezos.sender] := tokens;
  } with (noOperations, s)

function exitMarket(const qToken : address; var s : storage) : return is
  block {
    mustContainsQTokens(qToken, s);

    var tokens : set(address) := getAccountMembership(Tezos.sender, s);

    if not (tokens contains qToken) then
      failwith("NotEnter")
    else skip;

    if getAccountBorrows(Tezos.sender, qToken, s) =/= 0n then
      failwith("BorrowsExists")
    else skip;

    var ops := noOperations;
    for token in set tokens block {
      ops := Tezos.transaction(UpdateControllerState(Tezos.sender), 
             0mutez, 
             getUpdateControllerStateEntrypoint(token)) # ops;
    };

    ops := Tezos.transaction(record [
                                      user         = Tezos.sender;
                                      qToken       = qToken;
                                      redeemTokens = getAccountTokens(Tezos.sender, qToken, s);
                                      borrowAmount = getAccountBorrows(Tezos.sender, qToken, s);
                                    ],
           0mutez, 
           getRedeemMiddleEntrypoint(Tezos.self_address)) # ops;

    ops := Tezos.transaction(record [
                                      user         = Tezos.sender;
                                      qToken       = qToken;
                                      tokens       = tokens;
                                    ], 
           0mutez, 
           getEnsureExitMarketEntrypoint(Tezos.self_address)) # ops;
  } with (ops, s)

function ensureExitMarket(const user : address; const qToken : address; var tokens : set(address); var s : storage) : return is
  block {
    if Tezos.sender =/= Tezos.self_address then
      failwith("NotSelf")
    else skip;
    
    const response = 
    getUserLiquidity(user, qToken, getAccountTokens(user, qToken, s), getAccountBorrows(user, qToken, s), s);
    
    if response.shortfail =/= 0n then
      failwith("ShortfailNotZero")
    else skip;

    tokens := Set.remove(qToken, tokens);

    s.accountMembership[user] := tokens;
  } with (noOperations, s)

function safeMint(const amt : nat; const qToken : address; const s : storage) : return is
  block {
    mustContainsQTokens(qToken, s);
  } with (list [Tezos.transaction(record [
                                            user         = Tezos.sender;
                                            amt          = amt;
                                          ], 
         0mutez, 
         getMintEntrypoint(qToken))], s)

function safeRedeem(const amt : nat; const qToken : address; const s : storage) : return is
  block {
    mustContainsQTokens(qToken, s);

    const tokens : set(address) = getAccountMembership(Tezos.sender, s);
    var ops := noOperations;

    if tokens contains qToken then block {
      // update controller state for all users assets
      for token in set tokens block {
        ops := Tezos.transaction(UpdateControllerState(Tezos.sender), 
               0mutez, 
               getUpdateControllerStateEntrypoint(token)) # ops;
      };
      ops := Tezos.transaction(record [
                                        user         = Tezos.sender;
                                        qToken       = qToken;
                                        redeemTokens = amt;
                                        borrowAmount = getAccountBorrows(Tezos.sender, qToken, s);
                                      ], 
             0mutez, 
             getRedeemMiddleEntrypoint(Tezos.self_address)) # ops;
    }
    else ops := Tezos.transaction(record [
                                            user           = Tezos.sender;
                                            amt            = amt;
                                         ], 
                0mutez, 
                getRedeemEntrypoint(qToken)) # ops;
  } with (ops, s)

function redeemMiddle(const user : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : storage) : return is
  block {
    if Tezos.sender =/= Tezos.self_address then
      failwith("NotSelf")
    else skip;
  } with (list [Tezos.transaction(record [
                                            user         = user;
                                            qToken       = qToken;
                                            redeemTokens = redeemTokens;
                                            borrowAmount = borrowAmount;
                                          ], 
                0mutez, 
                getEnsuredRedeemEntrypoint(qToken))], s)

function ensuredRedeem(const user : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : storage) : return is
  block {
    if Tezos.sender =/= Tezos.self_address then
      failwith("NotSelf")
    else skip;

    const response = getUserLiquidity(user, qToken, redeemTokens, borrowAmount, s);
    if response.shortfail =/= 0n then
      failwith("ShortfailNotZero")
    else skip;

  } with (list [Tezos.transaction(record [
                                            user           = user;
                                            amt            = redeemTokens;
                                         ], 
                0mutez,
                getRedeemEntrypoint(qToken))], s)

function safeBorrow(const amt : nat; const qToken : address; var s : storage) : return is
  block {
    mustContainsQTokens(qToken, s);

    const tokens : set(address) = getAccountMembership(Tezos.sender, s);
    var ops := noOperations;

    if tokens contains qToken then skip;
    else block {
      const res = enterMarket(qToken, s);
      s := res.1;
    };
    //todo *ensure borrow amount smaller than max borrow limit (?)
    for token in set tokens block {
      ops := Tezos.transaction(UpdateControllerState(Tezos.sender), 
             0mutez, 
             getUpdateControllerStateEntrypoint(token)) # ops;
    };
    ops := Tezos.transaction(record [
                                      user         = Tezos.sender;
                                      qToken       = qToken;
                                      redeemTokens = amt;
                                      borrowAmount = getAccountBorrows(Tezos.sender, qToken, s);
                                    ],
                             0mutez, 
                             getBorrowMiddleEntrypoint(Tezos.self_address)) # ops;
  } with (ops, s)

function borrowMiddle(const user : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : storage) : return is
  block {
    if Tezos.sender =/= Tezos.self_address then
      failwith("NotSelf")
    else skip;
  } with (list [Tezos.transaction(record [
                                            user         = user;
                                            qToken       = qToken;
                                            redeemTokens = redeemTokens;
                                            borrowAmount = borrowAmount;
                                          ], 
                                  0mutez, 
                                  getEnsuredBorrowEntrypoint(Tezos.self_address))], s)

function ensuredBorrow(const user : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : storage) : return is
  block {
    if Tezos.sender =/= Tezos.self_address then
      failwith("NotSelf")
    else skip;

    const response = getUserLiquidity(user, qToken, redeemTokens, borrowAmount, s);
    if response.shortfail =/= 0n then
      failwith("ShortfailNotZero")
    else skip;

  } with (list [Tezos.transaction(record [
                                            user           = user;
                                            amt            = borrowAmount;
                                          ],
                                  0mutez, 
                                  getBorrowEntrypoint(qToken))], s)

function safeRepay(const amt : nat; const qToken : address; const s : storage) : return is
  block {
    mustContainsQTokens(qToken, s);
  } with (list [Tezos.transaction(record [
                                            user           = Tezos.sender;
                                            amt            = amt;
                                          ], 
         0mutez, 
         getRepayEntrypoint(qToken))], s)

function safeLiquidate(const borrower : address; const amt : nat; const qToken : address; var s : storage) : return is
  block {
    mustContainsQTokens(qToken, s);
    //todo *ensure repay amount smaller than max repay (?)
    const tokens : set(address) = getAccountMembership(Tezos.sender, s);
    var ops := noOperations;

    for token in set tokens block {
      ops := Tezos.transaction(UpdateControllerState(Tezos.sender), 
             0mutez, 
             getUpdateControllerStateEntrypoint(token)) # ops;
    };
    ops := Tezos.transaction(LiquidateMiddle(Tezos.sender, ((borrower, qToken), (amt, getAccountBorrows(borrower, qToken, s)))), 
                             0mutez, 
                             getLiquidateMiddleEntrypoint(Tezos.self_address)) # ops;
  } with (noOperations, s)

function liquidateMiddle(const liquidator : address; const borrower : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : storage) : return is
  block {
    if Tezos.sender =/= Tezos.self_address then
      failwith("NotSelf")
    else skip;
  } with (list [Tezos.transaction(EnsuredLiquidate(liquidator, ((borrower, qToken), (redeemTokens, borrowAmount))), 
                                  0mutez, 
                                  getEnsuredLiquidateEntrypoint(Tezos.self_address))], s)

function ensuredLiquidate(const liquidator : address; const borrower : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : storage) : return is
  block {
    if Tezos.sender =/= Tezos.self_address then
      failwith("NotSelf")
    else skip;

    const response = getUserLiquidity(borrower, qToken, redeemTokens, borrowAmount, s);
    if response.shortfail =/= 0n then
      failwith("ShortfailNotZero")
    else skip;

  } with (list [Tezos.transaction(Liquidate(liquidator, (borrower, redeemTokens)), 
                                  0mutez, 
                                  getLiquidateEntrypoint(qToken))], s)

function main(const action : entryAction; var s : storage) : return is
  block {
    skip
  } with case action of
    | UpdatePrice(params) -> updatePrice(params.0, params.1, s)
    | SetOracle(params) -> setOracle(params.0, params.1, s)
    | Register(params) -> register(params.0, params.1, s)
    | UpdateQToken(params) -> updateQToken(params.0.0, params.0.1, params.1.0, params.1.1, s)
    | EnterMarket(params) -> enterMarket(params, s)
    | ExitMarket(params) -> exitMarket(params, s)
    | EnsureExitMarket(params) -> ensureExitMarket(params.user, params.qToken, params.tokens, s)
    | SafeMint(params) -> safeMint(params.amt, params.qToken, s)
    | SafeRedeem(params) -> safeRedeem(params.amt, params.qToken, s)
    | RedeemMiddle(params) -> redeemMiddle(params.user, params.qToken, params.redeemTokens, params.borrowAmount, s)
    | EnsuredRedeem(params) -> ensuredRedeem(params.user, params.qToken, params.redeemTokens, params.borrowAmount, s)
    | SafeBorrow(params) -> safeBorrow(params.amt, params.qToken, s)
    | BorrowMiddle(params) -> borrowMiddle(params.user, params.qToken, params.redeemTokens, params.borrowAmount, s)
    | EnsuredBorrow(params) -> ensuredBorrow(params.user, params.qToken, params.redeemTokens, params.borrowAmount, s)
    | SafeRepay(params) -> safeRepay(params.amt, params.qToken, s)
  end;
