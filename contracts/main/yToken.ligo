#include "../partial/mainTypes.ligo"
#include "../partial/commonHelpers.ligo"
#include "../partial/yToken/lendingMethods.ligo"

function setUseAction(
  const idx             : nat;
  const lambda_bytes    : bytes;
  var s                 : fullStorage)
                        : fullReturn is
  block {
    if Tezos.sender = s.storage.admin
    then case s.useLambdas[idx] of
        Some(_n) -> failwith(Errors.yToken.lambdaSet)
        | None -> s.useLambdas[idx] := lambda_bytes
      end;
    else failwith(Errors.yToken.notAdmin)
  } with (noOperations, s)

function setTokenAction(
  const idx             : nat;
  const lambda_bytes    : bytes;
  var s                 : fullStorage)
                        : fullReturn is
  block {
    if Tezos.sender = s.storage.admin
    then case s.tokenLambdas[idx] of
        Some(_n) -> failwith(Errors.yToken.lambdaSet)
        | None -> s.tokenLambdas[idx] := lambda_bytes
      end;
    else failwith(Errors.yToken.notAdmin)
  } with (noOperations, s)

function callToken(
  const p               : tokenAction;
  var s                 : fullStorage)
                        : fullReturn is
  block {
    const idx : nat = case p of
      | ITransfer(_transferParams) -> 0n
      | IUpdate_operators(_updateOperatorParams) -> 1n
      | IBalance_of(_balanceParams) -> 2n
      | IGet_total_supply(_totalSupplyParams) -> 3n
    end;

    const lambda_bytes : bytes = unwrap(s.tokenLambdas[idx], Errors.yToken.lambdaNotSet);

    const res : return =
      case (Bytes.unpack(lambda_bytes) : option(tokenFunc)) of
        | Some(f) -> f(p, s.storage)
        | None -> failwith(Errors.yToken.unpackLambdaFailed)
      end;

    s.storage := res.1;
  } with (res.0, s)

[@inline] function callUse(
  const p               : useAction;
  var s                 : fullStorage)
                        : fullReturn is
  block {
      const idx : nat = case p of
        | Mint(_yAssetParams) -> 0n
        | Redeem(_yAssetParams) -> 1n
        | Borrow(_yAssetParams) -> 2n
        | Repay(_yAssetParams) -> 3n
        | Liquidate(_liquidateParams) -> 4n
        | EnterMarket(_tokenId) -> 5n
        | ExitMarket(_tokenId) -> 6n
        | SetAdmin(_addr) -> 7n
        | WithdrawReserve(_yAssetParams) -> 8n
        | SetTokenFactors(_setTokenParams) -> 9n
        | SetGlobalFactors(_setGlobalParams) -> 10n
        | SetBorrowPause(_tokenId) -> 11n
        | ApproveAdmin(_) -> 12n
      end;

    const lambda_bytes : bytes = unwrap(s.useLambdas[idx], Errors.yToken.lambdaNotSet);

    const res : return =
      case (Bytes.unpack(lambda_bytes) : option(useFunc)) of
        | Some(f) -> f(p, s.storage)
        | None -> failwith(Errors.yToken.unpackLambdaFailed)
      end;

    s.storage := res.1;
  } with (res.0, s)

function main(
  const p               : entryAction;
  const s               : fullStorage)
                        : fullReturn is
  case p of
    | Transfer(params)              -> callToken(ITransfer(params), s)
    | Update_operators(params)      -> callToken(IUpdate_operators(params), s)
    | Balance_of(params)            -> callToken(IBalance_of(params), s)
    | Get_total_supply(params)      -> callToken(IGet_total_supply(params), s)
    | UpdateInterest(params)        -> updateInterest(params, s)
    | AccrueInterest(params)        -> accrueInterest(params, s)
    | PriceCallback(params)         -> priceCallback(params, s)
    | AddMarket(params)             -> addMarket(params, s)
    | UpdateMetadata(params)        -> updateMetadata(params, s)
    | Use(params)                   -> callUse(params, s)
    | SetUseAction(params)          -> setUseAction(params.index, params.func, s)
    | SetTokenAction(params)        -> setTokenAction(params.index, params.func, s)
  end
