#include "../partials/IFactory.ligo"

const create_dex : create_dex_func =
[%Michelson ( {| { UNPPAIIR ;
                  CREATE_CONTRACT 
#include "../main/qToken.tz"
                  ;
                    PAIR } |}
           : create_dex_func)];


function getControllerContract(const controller_address : address) : contract(iController) is 
  case (Tezos.get_entrypoint_opt("%register", controller_address) : option(contract(iController))) of 
    Some(contr) -> contr
    | None -> (failwith("CantGetContractToken") : contract(iController))
  end;

(* Create the pool contract for Tez-Token pair *)
function launch_exchange (const self : address; const token : address; var s : exchange_storage) :  full_factory_return is
  block {
    case s.token_list[token] of 
    Some(t) -> failwith("Simular token")
    | None -> skip
    end;

    const storage : q_storage = record [
        owner = Tezos.sender;
        admin = Tezos.sender;
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
    const res : (operation * address) = create_dex((None : option(key_hash)), 0mutez, storage);

    s.token_list[token] := (res.1 : address);
  } with (list[res.0; Tezos.transaction(
    Register(record[token = token; qToken = res.1]),
    0mutez,
    getControllerContract(s.admin)
    )], s)

function main (const p : exchange_action; const s : exchange_storage) : full_factory_return is 
  case p of
    | LaunchExchange(params)    -> launch_exchange(Tezos.self_address, params.token, s)
  end
