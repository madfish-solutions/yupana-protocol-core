type exchangeStorage is record [
  tokenList           : big_map (address, address);
  owner               : address;
  admin               : address;
]

type borrows is
  record [
    amount           :nat;
    lastBorrowIndex  :nat;
    allowances       :map (address, nat);
  ]

type qStorage is
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

[@inline] const noOperations : list (operation) = nil;

type createContrFunc is (option(key_hash) * tez * qStorage) -> (operation * address)

type launchExchangeParams is record [
  token : address;
]

type fullFactoryReturn is list(operation) * exchangeStorage

type exchangeAction is 
| LaunchExchange        of launchExchangeParams
| SetAdmin              of address

type registerType is record [
    token        :address;
    qToken       :address;
] 

type iController is Register of registerType