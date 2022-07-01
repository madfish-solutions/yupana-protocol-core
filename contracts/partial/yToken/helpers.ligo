[@inline] function ensureNotZero(
  const amt             : nat)
                        : unit is
  require(amt > 0n, Errors.YToken.zeroAmount);

[@inline] function getBorrowRateContract(
  const rateAddress     : address)
                        : contract(rateParams) is
  unwrap(
    (Tezos.get_entrypoint_opt("%getBorrowRate", rateAddress): option(contract(rateParams))),
    Errors.YToken.borrowRate404
  )

(* Helper function to get account *)
[@inline] function getAccount(
  const user            : address;
  const tokenId         : tokenId;
  const accounts     : big_map((address * tokenId), account))
                        : account is
  case accounts[(user, tokenId)] of
    None -> record [
      allowances        = (set [] : set(address));
      borrow            = 0n;
      lastBorrowIndex   = 0n;
    ]
  | Some(v) -> v
  end

[@inline] function getTokenIds(
  const user            : address;
  const addressMap      : big_map(address, set(tokenId)))
                        : set(tokenId) is
  case addressMap[user] of
    None -> (set [] : set(tokenId))
  | Some(v) -> v
  end

(* Helper function to get token info *)
[@inline] function getToken(
  const token_id        : tokenId;
  const tokens          : big_map(tokenId, tokenType))
                        : tokenType is
  case tokens[token_id] of
    None -> record [
      mainToken               = FA12(zeroAddress);
      interestRateModel       = zeroAddress;
      priceUpdateTime         = zeroTimestamp;
      interestUpdateTime      = zeroTimestamp;
      totalBorrowsF           = 0n;
      totalLiquidF            = 0n;
      totalSupplyF            = 0n;
      totalReservesF          = 0n;
      borrowIndex             = precision;
      maxBorrowRate           = 0n;
      collateralFactorF       = 0n;
      reserveFactorF          = 0n;
      liquidReserveRateF      = 0n;
      lastPrice               = 0n;
      borrowPause             = False;
      enterMintPause          = False;
      isInterestUpdating      = False;
      threshold               = 0n;
    ]
  | Some(v) -> v
  end


(* Helper function to get acount balance by token *)
[@inline] function getBalanceByToken(
  const user            : address;
  const token_id        : nat;
  const ledger          : big_map((address * tokenId), nat))
                        : nat is
  case ledger[(user, token_id)] of
    None -> 0n
  | Some(v) -> v
  end

(* Validates the operators for the given transfer batch
 * and the operator storage.
 *)
[@inline] function isApprovedOperator(
  const transferParam   : transferParam;
  const token_id        : nat;
  const s               : yStorage)
                        : bool is
  block {
    const operator : address = Tezos.sender;
    const owner : address = transferParam.from_;
    const user : account = getAccount(owner, token_id, s.accounts);
  } with owner = operator or Set.mem(operator, user.allowances)

[@inline] function getLiquidity(
  const token           : tokenType)
                        : nat is
  get_nat_or_fail(token.totalLiquidF + token.totalBorrowsF - token.totalReservesF, Errors.Math.lowLiquidityReserve);


[@inline] function verifyInterestUpdated(
    const token         : tokenType)
                        : unit is
    require(token.interestUpdateTime >= Tezos.now, Errors.YToken.needUpdate)

[@inline] function verifyPriceUpdated(
    const token         : tokenType)
                        : unit is
    require(token.priceUpdateTime >= Tezos.now, Errors.YToken.needUpdate)

function calcMaxCollateralInCU(
  const userMarkets     : set(tokenId);
  const user            : address;
  const ledger          : big_map((address * tokenId), nat);
  const tokens          : big_map(tokenId, tokenType))
                        : nat is
  block {
    function oneToken(
      var acc           : nat;
      const tokenId     : tokenId)
                        : nat is
      block {
        const userBalance : nat = getBalanceByToken(user, tokenId, ledger);
        const token : tokenType = getToken(tokenId, tokens);
        if token.totalSupplyF > 0n then {
          const liquidityF : nat = getLiquidity(token);

          verifyPriceUpdated(token);
          verifyInterestUpdated(token);

          (* sum += collateralFactorF * exchangeRate * oraclePrice * balance *)
            acc := acc + userBalance * token.lastPrice
              * token.collateralFactorF * liquidityF / token.totalSupplyF / precision;
        }
        else skip;

      } with acc;
  } with Set.fold(oneToken, userMarkets, 0n)

function calcLiquidateCollateral(
  const userMarkets     : set(tokenId);
  const user            : address;
  const ledger          : big_map((address * tokenId), nat);
  const tokens          : big_map(tokenId, tokenType))
                        : nat is
  block {
    function oneToken(
      var acc           : nat;
      const tokenId     : tokenId)
                        : nat is
      block {
        const userBalance : nat = getBalanceByToken(user, tokenId, ledger);
        const token : tokenType = getToken(tokenId, tokens);
        if token.totalSupplyF > 0n then {
          const liquidityF : nat = getLiquidity(token);

          verifyPriceUpdated(token);
          verifyInterestUpdated(token);

          (* sum +=  balance * oraclePrice * exchangeRate *)
          acc := acc + userBalance * token.lastPrice * liquidityF / token.totalSupplyF;
        }
        else skip;
      } with acc * token.threshold / precision;
  } with Set.fold(oneToken, userMarkets, 0n)

function applyInterestToBorrows(
  const borrowedTokens  : set(tokenId);
  const user            : address;
  const accountsMap     : accountsMapType;
  const tokensMap       : big_map(tokenId, tokenType))
                        : accountsMapType is
  block {
    function oneToken(
      var userAccMap    : accountsMapType;
      const tokenId     : tokenId)
                        : accountsMapType is
      block {
        var userAccount : account := getAccount(user, tokenId, accountsMap);
        const token : tokenType = getToken(tokenId, tokensMap);

        verifyInterestUpdated(token);

        if userAccount.lastBorrowIndex =/= 0n
          then userAccount.borrow := userAccount.borrow * token.borrowIndex / userAccount.lastBorrowIndex;
        else
          skip;
        userAccount.lastBorrowIndex := token.borrowIndex;
      } with Map.update((user, tokenId), Some(userAccount), userAccMap);
  } with Set.fold(oneToken, borrowedTokens, accountsMap)

function calcOutstandingBorrowInCU(
  const userBorrow      : set(tokenId);
  const user            : address;
  const accounts        : big_map((address * tokenId), account);
  const ledger          : big_map((address * tokenId), nat);
  const tokens          : big_map(tokenId, tokenType))
                        : nat is
  block {
    function oneToken(
      var acc           : nat;
      var tokenId       : tokenId)
                        : nat is
      block {
        const userAccount : account = getAccount(user, tokenId, accounts);
        const userBalance : nat = getBalanceByToken(user, tokenId, ledger);
        var token : tokenType := getToken(tokenId, tokens);

        verifyPriceUpdated(token);

        (* sum += oraclePrice * borrow *)
        if userBalance > 0n or userAccount.borrow > 0n
        then acc := acc + userAccount.borrow * token.lastPrice;
        else skip;
      } with acc;
  } with Set.fold(oneToken, userBorrow, 0n)

[@inline] function getFA12Transfer(
  const tokenAddress    : address)
                        : contract(transferType) is
  unwrap(
    (Tezos.get_entrypoint_opt("%transfer", tokenAddress)
                        : option(contract(transferType))),
    Errors.FA12.wrongContract
  );

[@inline] function getFA2Transfer(
  const tokenAddress    : address)
                        : contract(iterTransferType) is
  unwrap(
    (Tezos.get_entrypoint_opt("%transfer", tokenAddress)
                        : option(contract(iterTransferType))),
    Errors.FA2.wrongContract
  );

[@inline] function wrap_fa12_transfer_trx(
  const from_           : address;
  const to_             : address;
  const amt             : nat)
                        : transferType is
  TransferOutside((from_, (to_, amt)))

[@inline] function wrap_fa2_transfer_trx(
  const from_           : address;
  const to_             : address;
  const amt             : nat;
  const id              : nat)
                        : iterTransferType is
  FA2TransferOutside(list[(from_, list[
        (to_, (id, amt))
    ])])

[@inline] function transfer_fa12(
  const from_           : address;
  const to_             : address;
  const amt             : nat;
  const token           : address)
                        : list(operation) is
  list[Tezos.transaction(
    wrap_fa12_transfer_trx(from_, to_, amt),
    0mutez,
    getFA12Transfer(token)
  )];

[@inline] function transfer_fa2(
  const from_           : address;
  const to_             : address;
  const amt             : nat;
  const token           : address;
  const id              : nat)
                        : list(operation) is
  list[Tezos.transaction(
    wrap_fa2_transfer_trx(from_, to_, amt, id),
    0mutez,
    getFA2Transfer(token)
  )];

[@inline] function transfer_token(
  const from_           : address;
  const to_             : address;
  const amt             : nat;
  const token           : assetType)
                        : list(operation) is
  case token of
    FA12(token) -> transfer_fa12(from_, to_, amt, token)
  | FA2(token)  -> transfer_fa2(from_, to_, amt, token.0, token.1)
  end