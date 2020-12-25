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

type entryAction is
  | UpdatePrice of address * nat

type mint_type is Mint of michelson_pair(address, "user", nat, "amount")
type updateControllerState_type is UpdateControllerState of address
type redeemMiddle_type is RedeemMiddle of michelson_pair(michelson_pair(address, "user", address, "qToken"), "", 
                                                         michelson_pair(nat, "redeemTokens", nat, "borrowAmount"), "")
type redeem_type is Redeem of michelson_pair(address, "user", nat, "amount")
type ensuredRedeem_type is EnsuredRedeem of michelson_pair(michelson_pair(address, "user", address, "qToken"), "", 
                                            michelson_pair(nat, "redeemTokens", nat, "borrowAmount"), "")



// function getQTokens(const s : storage) : set(address) is
//   case s.qTokens of
//     Some (value) -> value
//   | None -> (set [] : set(address))
//   end;

//todo do i deen this function
// function getPair(const underlyingToken : address; const s : storage) : address is
//   case s.pairs[underlyingToken] of
//     Some (value) -> value
//   | None -> zeroAddress
//   end;

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

function getUserLiquidity(const user : address; const qToken : address; const redeemTokens : nat; const borrowAmount : nat; var s : storage) : michelson_pair(nat, "surplus", nat, "shortfail") is
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
[@inline] function mustContainsQTokens(const qToken : address; const s : storage) : unit is
  block {
    if (s.qTokens contains qToken) = False then
      failwith("NotContains")
    else skip;
  } with (unit)

// check that input address NOT contains in storage.qTokens
// will throw an exception if contains
[@inline] function mustNotContainsQTokens(const qToken : address; const s : storage) : unit is
  block {
    if (s.qTokens contains qToken) = True then
      failwith("Contains")
    else skip;
  } with (unit)

[@inline] function mustBeSelf(const u : unit) : unit is
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

// function safeBorrow(const amt : nat; const qToken : address; var s : storage)

function main(const action : entryAction; var s : storage) : return is
  block {
    skip
  } with case action of
    | UpdatePrice(params) -> updatePrice(params.0, params.1, s)
  end;
