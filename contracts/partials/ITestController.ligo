type storage is
  record [
    factory           :address;
    admin             :address;
    qTokens           :set(address);
    pairs             :big_map(address, address);
  ]

type registerParams is record [
    token        :address;
    qToken       :address;
]

[@inline] const noOperations : list (operation) = nil;

type return is list (operation) * storage;

[@inline] const noOperations : list (operation) = nil;

type entryAction is 
    | SetFactory of address
    | Register of registerParams
