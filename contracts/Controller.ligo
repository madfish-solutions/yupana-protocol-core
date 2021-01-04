const zeroAddress : address = ("tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg" : address);
const sumCollateral : nat = 0n;
const sumBorrow : nat = 0n;

type marketInfo is
  record [
    collateralFactor  :nat;
    lastPrice         :nat;
    oracle            :address;
    exchangeRate      :nat;
    users             :set(address)
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
  ]
//all numbers in storage are real numbers
const accuracy : nat = 1000000000000000000n; //1e+18

type return is list (operation) * storage
[@inline] const noOperations : list (operation) = nil;

type mint_type is Mint of michelson_pair(address, "user", nat, "amount")
type updateControllerState_type is UpdateControllerState of address
type redeemMiddle_type is RedeemMiddle of michelson_pair(michelson_pair(address, "user", address, "qToken"), "", 
                                                         michelson_pair(nat, "redeemTokens", nat, "borrowAmount"), "")
type redeem_type is Redeem of michelson_pair(address, "user", nat, "amount")
type ensuredRedeem_type is EnsuredRedeem of michelson_pair(michelson_pair(address, "user", address, "qToken"), "", 
                                            michelson_pair(nat, "redeemTokens", nat, "borrowAmount"), "")
type borrow_type is Borrow of michelson_pair(address, "user", nat, "amount")
type borrowMiddle_type is BorrowMiddle of michelson_pair(michelson_pair(address, "user", address, "qToken"), "", 
                                                         michelson_pair(nat, "redeemTokens", nat, "borrowAmount"), "")
type ensuredBorrow_type is EnsuredBorrow of michelson_pair(michelson_pair(address, "user", address, "qToken"), "", 
                                                           michelson_pair(nat, "redeemTokens", nat, "borrowAmount"), "")
type repay_type is Repay of michelson_pair(address, "user", nat, "amount")
type liquidateMiddle_type is LiquidateMiddle of michelson_pair(address, "liquidator", michelson_pair(michelson_pair(address, "borrower", address, "qToken"), "", 
                                                                                                     michelson_pair(nat, "redeemTokens", nat, "borrowAmount"), ""), "")
type ensuredLiquidate_type is EnsuredLiquidate of michelson_pair(address, "liquidator", michelson_pair(michelson_pair(address, "borrower", address, "qToken"), "", 
                                                                                                       michelson_pair(nat, "redeemTokens", nat, "borrowAmount"), ""), "")
type liquidate_type is Liquidate of michelson_pair(address, "liquidator", michelson_pair(address, "borrower", nat, "amount"), "")

type entryAction is
  | UpdatePrice of michelson_pair(address, "qToken", nat, "price")
  | SetOracle of michelson_pair(address, "qToken", address, "oracle")
  | Register of michelson_pair(address, "token", address, "qToken")
  | UpdateQToken of michelson_pair(michelson_pair(address, "user", nat, "balance"), "", michelson_pair(nat, "borrow", nat, "exchangeRate"), "")
  | EnterMarket of address
  | ExitMarket of address
  | SafeMint of michelson_pair(nat, "amount", address, "qToken")
  | SafeRedeem of michelson_pair(nat, "amount", address, "qToken")
  // | RedeemMiddleAction of redeemMiddle_type
  // | EnsuredRedeemAction of ensuredRedeem_type
  // | SafeBorrow of michelson_pair(nat, "amount", address, "qToken")
  // | BorrowMiddleAction of borrowMiddle_type
  // | EnsuredBorrowAction of ensuredBorrow_type
  // | SafeRepay of michelson_pair(nat, "amount", address, "qToken")
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
        users            = (set [] : set(address));
      ];
    case s.markets[qToken] of
      None -> skip
    | Some(value) -> m := value
    end;
  } with m

function getMintEntrypoint(const token_address : address) : contract(mint_type) is
  case (Tezos.get_entrypoint_opt("%mint", token_address) : option(contract(mint_type))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetMintEntrypoint") : contract(mint_type))
  end;

function getUpdateControllerStateEntrypoint(const token_address : address) : contract(updateControllerState_type) is
  case (Tezos.get_entrypoint_opt("%updateControllerState", token_address) : option(contract(updateControllerState_type))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetUpdateControllerStateEntrypoint") : contract(updateControllerState_type))
  end;

function getRedeemMiddleEntrypoint(const token_address : address) : contract(redeemMiddle_type) is
  case (Tezos.get_entrypoint_opt("%redeemMiddle", token_address) : option(contract(redeemMiddle_type))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetRedeemMiddleEntrypoint") : contract(redeemMiddle_type))
  end;

function getRedeemEntrypoint(const token_address : address) : contract(redeem_type) is
  case (Tezos.get_entrypoint_opt("%redeem", token_address) : option(contract(redeem_type))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetRedeemEntrypoint") : contract(redeem_type))
  end;

function getEnsuredRedeemEntrypoint(const token_address : address) : contract(ensuredRedeem_type) is
  case (Tezos.get_entrypoint_opt("%ensuredRedeem", token_address) : option(contract(ensuredRedeem_type))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetEnsuredRedeemEntrypoint") : contract(ensuredRedeem_type))
  end;

function getBorrowEntrypoint(const token_address : address) : contract(borrow_type) is
  case (Tezos.get_entrypoint_opt("%borrow", token_address) : option(contract(borrow_type))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetBorrowEntrypoint") : contract(borrow_type))
  end;

function getBorrowMiddleEntrypoint(const token_address : address) : contract(borrowMiddle_type) is
  case (Tezos.get_entrypoint_opt("%borrowMiddle", token_address) : option(contract(borrowMiddle_type))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetBorrowMiddleEntrypoint") : contract(borrowMiddle_type))
  end;

function getEnsuredBorrowEntrypoint(const token_address : address) : contract(ensuredBorrow_type) is
  case (Tezos.get_entrypoint_opt("%ensuredBorrow", token_address) : option(contract(ensuredBorrow_type))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetEnsuredBorrowEntrypoint") : contract(ensuredBorrow_type))
  end;

function getRepayEntrypoint(const token_address : address) : contract(repay_type) is
  case (Tezos.get_entrypoint_opt("%repay", token_address) : option(contract(repay_type))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetRepayEntrypoint") : contract(repay_type))
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

function getUserLiquidity(const user : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : storage) : michelson_pair(nat, "surplus", nat, "shortfail") is
  block {
    sumCollateral := 0n;
    sumBorrow := 0n;
    var tokensToDenom : nat := 0n;
    var m : marketInfo := getMarket(qToken, s);

    for token in set s.qTokens block {
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

    var surplus : nat := 0n;
    var shortfail : nat := 0n;

    if sumCollateral > sumBorrow then
      surplus := abs(sumCollateral - sumBorrow);
    else skip;

    if sumBorrow > sumCollateral then
      shortfail := abs(sumBorrow - sumCollateral);
    else skip;

  } with (surplus, shortfail)

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

function mustBeSelf(const u : unit) : unit is
  block {
    if Tezos.sender =/= Tezos.self_address then
      failwith("NotSelf")
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

    var market : marketInfo := getMarket(qToken, s);

    if market.users contains Tezos.sender then
      failwith("AlreadyEnter")
    else skip;

    var m : marketInfo := getMarket(zeroAddress, s);
    var counter : nat := 0n;
    for token in set s.qTokens block {
      m := getMarket(token, s);
      if m.users contains Tezos.sender then
        counter := counter + 1n;
      else skip;
    };

    if counter >= 4n then
      failwith("LimitExceeded")
    else skip;

    market.users := Set.add(Tezos.sender, market.users);

    s.markets[qToken] := market;
  } with (noOperations, s)

function exitMarket(const qToken : address; var s : storage) : return is
  block {
    mustContainsQTokens(qToken, s);

    var market : marketInfo := getMarket(qToken, s);

    if (market.users contains Tezos.sender) = False then
      failwith("NotEnter")
    else skip;

    if getAccountBorrows(Tezos.sender, qToken, s) =/= 0n then
      failwith("BorrowsExists")
    else skip;

    // todo after redeem?
    const pair = getUserLiquidity(Tezos.sender, qToken, getAccountTokens(Tezos.sender, qToken, s), 0n, s);
    
    if pair.1 =/= 0n then
      failwith("ShortfailNotZero")
    else skip;

    market.users := Set.remove(Tezos.sender, market.users);

    s.markets[qToken] := market;
  } with (noOperations, s)

function safeMint(const amt : nat; const qToken : address; const s : storage) : return is
  block {
    mustContainsQTokens(qToken, s);
  } with (list [Tezos.transaction(Mint(Tezos.sender, amt), 
         0mutez, 
         getMintEntrypoint(qToken))], s)

function safeRedeem(const amt : nat; const qToken : address; const s : storage) : return is
  block {
    mustContainsQTokens(qToken, s);

    var market : marketInfo := getMarket(qToken, s);
    var ops := noOperations;

    if market.users contains Tezos.sender then block {
      // update controller state for all users assets
      for token in set s.qTokens block {
        market := getMarket(token, s);
        if market.users contains Tezos.sender then
          ops := Tezos.transaction(UpdateControllerState(Tezos.sender), 
                 0mutez, 
                 getUpdateControllerStateEntrypoint(qToken)) # ops;
        else skip;
      };
      //todo will it self call?
      ops := Tezos.transaction(RedeemMiddle((Tezos.sender, qToken), (amt, getAccountBorrows(Tezos.sender, qToken, s))), 
             0mutez, 
             getRedeemMiddleEntrypoint(Tezos.self_address)) # ops;
    }
    else ops := Tezos.transaction(Redeem(Tezos.sender, amt), 
                0mutez, 
                getRedeemEntrypoint(qToken)) # ops;
  } with (ops, s)

function redeemMiddle(const user : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : storage) : return is
  block {
    mustBeSelf(unit);
  } with (list [Tezos.transaction(EnsuredRedeem((user, qToken), (redeemTokens, borrowAmount)), 
                0mutez, 
                getEnsuredRedeemEntrypoint(qToken))], s)

function ensuredRedeem(const user : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : storage) : return is
  block {
    mustBeSelf(unit);

    const pair = getUserLiquidity(user, qToken, redeemTokens, borrowAmount, s);
    if pair.1 =/= 0n then
      failwith("ShortfailNotZero")
    else skip;

  } with (list [Tezos.transaction(Redeem(user, redeemTokens),
                0mutez,
                getRedeemEntrypoint(qToken))], s)

function safeBorrow(const amt : nat; const qToken : address; var s : storage) : return is
  block {
    mustContainsQTokens(qToken, s);

    var market : marketInfo := getMarket(qToken, s);
    var ops := noOperations;

    if market.users contains Tezos.sender then skip;
    else block {
      const res = enterMarket(qToken, s);
      s := res.1;
    };
    //todo *ensure borrow amount smaller than max borrow limit (?)
    for token in set s.qTokens block {
      market := getMarket(token, s);
      if market.users contains Tezos.sender then
        ops := Tezos.transaction(UpdateControllerState(Tezos.sender), 
               0mutez, 
               getUpdateControllerStateEntrypoint(qToken)) # ops;
      else skip;
    };
    //todo will it self call?
    ops := Tezos.transaction(BorrowMiddle((Tezos.sender, qToken), (amt, getAccountBorrows(Tezos.sender, qToken, s))), 
                             0mutez, 
                             getBorrowMiddleEntrypoint(Tezos.self_address)) # ops;
  } with (ops, s)

function borrowMiddle(const user : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : storage) : return is
  block {
    mustBeSelf(unit);
  } with (list [Tezos.transaction(EnsuredBorrow((user, qToken), (redeemTokens, borrowAmount)), 
                                  0mutez, 
                                  getEnsuredBorrowEntrypoint(Tezos.self_address))], s)

function ensuredBorrow(const user : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : storage) : return is
  block {
    mustBeSelf(unit);

    const pair = getUserLiquidity(user, qToken, redeemTokens, borrowAmount, s);
    if pair.1 =/= 0n then
      failwith("ShortfailNotZero")
    else skip;

  } with (list [Tezos.transaction(Borrow(user, borrowAmount), 
                                  0mutez, 
                                  getBorrowEntrypoint(qToken))], s)

function safeRepay(const amt : nat; const qToken : address; const s : storage) : return is
  block {
    mustContainsQTokens(qToken, s);
  } with (list [Tezos.transaction(Repay(Tezos.sender, amt), 
         0mutez, 
         getRepayEntrypoint(qToken))], s)

function safeLiquidate(const borrower : address; const amt : nat; const qToken : address; var s : storage) : return is
  block {
    mustContainsQTokens(qToken, s);
    //todo *ensure repay amount smaller than max repay (?)
    var market : marketInfo := getMarket(qToken, s);
    var ops := noOperations;

    for token in set s.qTokens block {
      market := getMarket(token, s);
      if market.users contains Tezos.sender then
        ops := Tezos.transaction(UpdateControllerState(Tezos.sender), 
               0mutez, 
               getUpdateControllerStateEntrypoint(qToken)) # ops;
      else skip;
    };
    //todo will it self call?
    ops := Tezos.transaction(LiquidateMiddle(Tezos.sender, ((borrower, qToken), (amt, getAccountBorrows(borrower, qToken, s)))), 
                             0mutez, 
                             getLiquidateMiddleEntrypoint(Tezos.self_address)) # ops;
  } with (noOperations, s)

function liquidateMiddle(const liquidator : address; const borrower : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : storage) : return is
  block {
    mustBeSelf(unit);
  } with (list [Tezos.transaction(EnsuredLiquidate(liquidator, ((borrower, qToken), (redeemTokens, borrowAmount))), 
                                  0mutez, 
                                  getEnsuredLiquidateEntrypoint(Tezos.self_address))], s)

function ensuredLiquidate(const liquidator : address; const borrower : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; const s : storage) : return is
  block {
    mustBeSelf(unit);

    const pair = getUserLiquidity(borrower, qToken, redeemTokens, borrowAmount, s);
    if pair.1 =/= 0n then
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
    | SafeMint(params) -> safeMint(params.0, params.1, s)
    | SafeRedeem(params) -> safeRedeem(params.0, params.1, s)
    // | RedeemMiddleAction(params) -> redeemMiddle(params.0.0.0, params.0.0.1, params.0.1.0, params.0.1.1, s)
  end;
