#include "./IqToken.ligo"

type factoryStorage is record [
  tokenList           : big_map(address, address);
  owner               : address;
  admin               : address;
  tokenLambdas        : big_map(nat, tokenFunc);
  useLambdas          : big_map(nat, useFunc);
]

type createContrFunc is (option(key_hash) * tez * fullTokenStorage) -> (operation * address)

type launchTokenParams is record [
  token : address;
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
    token        :address;
    qToken       :address;
]

type iController is Register of registerType
type fullFactoryReturn is list(operation) * factoryStorage

type factoryAction is 
| LaunchToken           of launchTokenParams
| SetFactoryAdmin       of address
| SetTokenFunction      of setTokenParams
| SetUseFunction        of setUseParams
