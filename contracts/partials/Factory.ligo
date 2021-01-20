#include "./IFactory.ligo"

const create_dex : create_dex_func =
[%Michelson ( {| { UNPPAIIR ;
                  CREATE_CONTRACT 
#include "../main/qToken.tz"
                  ;
                    PAIR } |}
           : create_dex_func)];
  
(* Create the pool contract for Tez-Token pair *)
function launch_exchange (const self : address; const token : address; var s : exchange_storage) :  full_factory_return is
  block {
    // if s.token_list[(self : address)] token then
    //   failwith("Factory/exchange-launched")
    // else skip;
    s.token_list[(self : address)] := token;

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
  } with (list[res.0], s)

function main (const p : exchange_action; const s : exchange_storage) : full_factory_return is 
  case p of
    | LaunchExchange(params)    -> launch_exchange(Tezos.self_address, params.token, s)
  end
