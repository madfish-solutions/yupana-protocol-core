type exchange_storage is record [
  token_list          : big_map (address, address);
  owner               : address;
  admin               : address;
]

type borrows is
  record [
    amount           :nat;
    lastBorrowIndex  :nat;
    allowances       :map (address, nat);
  ]

type q_storage is
  record [
    owner           :address;
    admin           :address;
    token           :address;
    lastUpdateTime  :timestamp;
    totalBorrows    :nat;
    totalLiquid     :nat;
    totalSupply     :nat;
    totalReserves   :nat;
    borrowIndex     :nat;
    accountBorrows  :big_map(address, borrows);
    accountTokens   :big_map(address, nat);
  ]

type create_dex_func is (option(key_hash) * tez * q_storage) -> (operation * address)

type launch_exchange_params is record [
  token : address;
]

type full_factory_return is list(operation) * exchange_storage

type exchange_action is 
| LaunchExchange        of launch_exchange_params
