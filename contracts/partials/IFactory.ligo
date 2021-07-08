#include "./MainTypes.ligo"

type factoryStorage is record [
  tokenList           : big_map(address, address);
  owner               : address;
  admin               : address;
  tokenLambdas        : big_map(nat, tokenFunc);
  useLambdas          : big_map(nat, useFunc);
]

type createContrFunc is (option(key_hash) * tez * fullTokenStorage) -> (operation * address)

type launchTokenParams is record [
  token           : address;
  oralcePairName  : string;
]

type setTokenParams is record [
  index  : nat;
  func   : tokenFunc;
]

type setUseParams is record [
  index  : nat;
  func   : useFunc;
]

type registerType is record [
    token        : address;
    qToken       : address;
    pairName     : string;
]

type iController is QRegister of registerType
type fullFactoryReturn is list(operation) * factoryStorage

type factoryAction is
| LaunchToken           of launchTokenParams
| SetFactoryAdmin       of address
| SetNewOwner           of address
| SetTokenFunction      of setTokenParams
| SetUseFunction        of setUseParams
