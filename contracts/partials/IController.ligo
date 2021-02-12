#include "./IqToken.ligo"

type market is record [
  collateralFactor      : nat;
  lastPrice             : nat;
  oracle                : address;
  exchangeRate          : nat;
]

type membershipParams is record [
  borrowerToken         : address;
  collateralToken       : address;
]

type controllerStorage is record [
  factory               : address;
  admin                 : address;
  qTokens               : set(address);
  pairs                 : big_map(address, address);
  accountBorrows        : big_map((address * address), nat);
  accountTokens         : big_map((address * address), nat);
  markets               : big_map(address, market);
  accountMembership     : big_map(address, membershipParams);
]

type updateParams is record [
  qToken                : address;
  price                 : nat;
]

type setOracleParams is record [
  qToken                : address;
  oracle                : address;
]

type registerParams is record [
  qToken                : address;
  token                 : address;
]

type updateQTokenParams is [@layout:comb] record [
  user                  : address;
  balance               : nat;
  borrow                : nat;
  exchangeRate          : nat;
]

type getUserLiquidityParams is record [
  user                  : address;
  qToken                : address;
  redeemTokens          : nat;
  borrowAmount          : nat;
]

type getUserLiquidityReturn is record [
  surplus               : nat;
  shortfail             : nat;
]

type safeMintParams is record [
  qToken                : address;
  amount                : nat;
]

type safeRedeemParams is record [
  qToken                : address;
  amount                : nat;
]

type redeemMiddleParams is record [
  user                  : address;
  qToken                : address;
  redeemTokens          : nat;
  borrowAmount          : nat;
]

type redeemType is record [
  user                  : address;
  amount                : nat;
]

type ensuredRedeemParams is record [
  user                  : address;
  qToken                : address;
  redeemTokens          : nat;
  borrowAmount          : nat;
]

type safeBorrowParams is record [
  qToken                : address;
  amount                : nat;
  borrowerToken         : address;
]

type borrowMiddleParams is record [
  user                  : address;
  qToken                : address;
  redeemTokens          : nat;
  borrowAmount          : nat;
]

type borrowParams is record [
  user                  : address;
  amount                : nat;
]

type repayParams is record [
  user                  : address;
  amount                : nat;
]

type ensuredBorrowParams is record [
  user                  : address;
  qToken                : address;
  redeemTokens          : nat;
  borrowAmount          : nat; 
]

type safeRepayParams is record [
  qToken                : address;
  amount                : nat;
]

type safeLiquidateParams is record [
  borrower              : address;
  amount                : nat;
  qToken                : address;
]

type liquidateMiddleParams is record [
  user                  : address;
  borrower              : address;
  qToken                : address;
  redeemTokens          : nat;
  borrowAmount          : nat;
]

type liquidateType is record [
  liquidator            : address;
  borrower              : address;
  amount                : nat;
]

type ensuredLiquidateParams is record [
  user                  : address;
  borrower              : address;
  qToken                : address;
  redeemTokens          : nat;
  borrowAmount          : nat;
]

type useControllerAction is 
  | UpdatePrice of updateParams
  | SetOracle of setOracleParams
  | Register of registerParams
  | UpdateQToken of updateQTokenParams
  | EnterMarket of membershipParams
  | ExitMarket of membershipParams
  | SafeMint of safeMintParams
  | SafeRedeem of safeRedeemParams
  | RedeemMiddle of redeemMiddleParams
  | EnsuredRedeem of ensuredRedeemParams
  | SafeBorrow of safeBorrowParams
  | BorrowMiddle of borrowMiddleParams
  | EnsuredBorrow of ensuredBorrowParams
  | SafeRepay of safeRepayParams
  | SafeLiquidate of safeLiquidateParams
  | LiquidateMiddle of liquidateMiddleParams
  | EnsuredLiquidate of ensuredLiquidateParams

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
