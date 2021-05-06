#include "./MainTypes.ligo"

type market is record [
  collateralFactor      : nat;
  lastPrice             : nat;
  // oracle                : address;
  exchangeRate          : nat;
  // oraclePairName        : string; // !!!!
]

type controllerStorage is record [
  factory               : address;
  admin                 : address;
  qTokens               : set(address);
  oraclePairs           : big_map(address, string); // !!!!
  oracleStringPairs     : big_map(string, address); // !!!!
  pairs                 : big_map(address, address);
  accountBorrows        : big_map((address * address), nat);
  accountTokens         : big_map((address * address), nat);
  markets               : big_map(address, market);
  accountMembership     : big_map(address, membershipParams);
  oracle                : address; // !!!!
]

[@inline] const noOperations : list (operation) = nil
type return is list (operation) * controllerStorage
type useControllerFunc is (useControllerAction  * address * controllerStorage) -> return
const accuracy : nat = 1000000000000000000n; //1e+18
type updateControllerStateType is QUpdateControllerState of address

type setUseParams is record [
  index                 : nat;
  func                  : useControllerFunc;
]

type fullControllerStorage is record [
  storage               : controllerStorage;
  useControllerLambdas  : big_map(nat, useControllerFunc);
]

type fullReturn is list (operation) * fullControllerStorage

type entryAction is
  | UseController of useControllerAction
  | SetUseAction of setUseParams
  | SetFactory of address
