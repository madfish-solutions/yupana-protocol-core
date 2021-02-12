#include "../partials/IFactory.ligo"
#include "../partials/qTokenMethods.ligo"

const createContr : createContrFunc =
[%Michelson ( {| { UNPPAIIR ;
                  CREATE_CONTRACT 
#include "../main/qToken.tz"
                  ;
                    PAIR } |}
           : createContrFunc)];

function setTokenFunction (const idx : nat; const f : tokenFunc; const s : factoryStorage) : fullFactoryReturn is
  block {
    case s.tokenLambdas[idx] of 
      Some(n) -> failwith("Factory/function-set")
      | None -> s.tokenLambdas[idx] := f 
    end;
  } with (noOperations, s)

function setUseFunction (const idx : nat; const f : useFunc; const s : factoryStorage) : fullFactoryReturn is
  block {
    case s.useLambdas[idx] of 
      Some(n) -> failwith("Factory/function-set") 
      | None -> s.useLambdas[idx] := f
    end;
  } with (noOperations, s)

[@inline] function getControllerContract (const controllerAddress : address) : contract(iController) is 
  case (Tezos.get_entrypoint_opt("%register", controllerAddress) : option(contract(iController))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetContractToken") : contract(iController))
  end;

function setFactoryAdmin (const newAdmin : address; var s : factoryStorage) : fullFactoryReturn is
  block {
    if Tezos.sender =/= s.owner then
      failwith("NotOwner")
    else skip;
    s.admin := newAdmin;
  } with (noOperations, s)

function launchToken (const token : address; var s : factoryStorage) : fullFactoryReturn is
  block {
    case s.tokenList[token] of 
    Some(t) -> failwith("Simular token")
    | None -> skip
    end;

    const storage : tokenStorage = record [
        owner = s.owner;
        admin = s.admin;
        token = token;
        lastUpdateTime = Tezos.now;
        totalBorrows = 0n;
        totalLiquid = 0n;
        totalSupply = 0n;
        totalReserves = 0n;
        borrowIndex = 0n;
        accountBorrows = (big_map [] : big_map(address, borrows));
        accountTokens = (big_map [] : big_map(address, nat));
    ];

    const fullStorage : fullTokenStorage = record [
      storage = storage;
      tokenLambdas = (big_map [] : big_map(nat, tokenFunc));
      useLambdas = (big_map [] : big_map(nat, useFunc));
    ];

    const res : (operation * address) = createContr((None : option(key_hash)), 0mutez, fullStorage);

    s.tokenList[token] := (res.1);
  } with (list[res.0; Tezos.transaction(
    Register(record[token = token; qToken = res.1]),
    0mutez,
    getControllerContract(s.admin)
    )], s)

function main (const p : factoryAction; const s : factoryStorage) : fullFactoryReturn is 
  case p of
    | LaunchToken(params)           -> launchToken(params.token, s)
    | SetFactoryAdmin(params)       -> setFactoryAdmin(params, s)
    | SetTokenFunction(params)      -> setTokenFunction(params.index, params.func, s)
    | SetUseFunction(params)        -> setUseFunction(params.index, params.func, s)
  end
