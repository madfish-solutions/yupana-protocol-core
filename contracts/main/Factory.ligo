#include "../partials/IFactory.ligo"

const createContr : createContrFunc =
[%Michelson ( {| { UNPPAIIR ;
                  CREATE_CONTRACT 
#include "../main/qToken.tz"
                  ;
                    PAIR } |}
           : createContrFunc)];


[@inline] function mustBeOwner(const s : exchangeStorage) : unit is
  block {
    if Tezos.sender =/= s.owner then
      failwith("NotOwner")
    else skip;
  } with (unit)

function getControllerContract(const controllerAddress : address) : contract(iController) is 
  case (Tezos.get_entrypoint_opt("%register", controllerAddress) : option(contract(iController))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetContractToken") : contract(iController))
  end;

function setAdmin(const newAdmin : address; var s : exchangeStorage) : fullFactoryReturn is
  block {
    mustBeOwner(s);
    s.admin := newAdmin;
  } with (noOperations, s)

(* Create the pool contract for Tez-Token pair *)
function launchExchange (const self : address; const token : address; var s : exchangeStorage) :  fullFactoryReturn is
  block {
    case s.tokenList[token] of 
    Some(t) -> failwith("Simular token")
    | None -> skip
    end;

    const storage : qStorage = record [
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
    const res : (operation * address) = createContr((None : option(key_hash)), 0mutez, storage);

    s.tokenList[token] := (res.1 : address);
  } with (list[res.0; Tezos.transaction(
    Register(record[token = token; qToken = res.1]),
    0mutez,
    getControllerContract(s.admin)
    )], s)

function main (const p : exchangeAction; const s : exchangeStorage) : fullFactoryReturn is 
  case p of
    | LaunchExchange(params)    -> launchExchange(Tezos.self_address, params.token, s)
    | SetAdmin(params)          -> setAdmin(params, s)
  end
