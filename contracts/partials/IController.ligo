type market is record [
  collateralFactor      : nat;
  lastPrice             : nat;
  oracle                : address;
  exchangeRate          : nat;
]

type controllerStorage is record [
  factory               : address;
  admin                 : address;
  qTokens               : set(address);
  pairs                 : big_map(address, address);
  accountBorrows        : big_map((address * address), nat);
  accountTokens         : big_map((address * address), nat);
  markets               : big_map(address, market);
  accountMembership     : big_map(address, address);
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
  token                 : address;
  qToken                : address;
]

type updateQTokenParams is record [
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

type safeMintParams is record [
  amount                : nat;
  qToken                : address;
]

type safeRedeemParams is record [
  amount                : nat;
  qToken                : address;
]

type redeemMiddleParams is record [
  user                  : address;
  qToken                : address;
  redeemTokens          : nat;
  borrowAmount          : nat;
]

type ensuredRedeemParams is record [
  user                  : address;
  qToken                : address;
  redeemTokens          : nat;
  borrowAmount          : nat;
]

type safeBorrowParams is record [
  amount                : nat;
  qToken                : address;
]

type borrowMiddleParams is record [
  user                  : address;
  qToken                : address;
  redeemTokens          : nat;
  borrowAmount          : nat;
]

type ensuredBorrowParams is record [
  user                  : address;
  qToken                : address;
  redeemTokens          : nat;
  borrowAmount          : nat; 
]

type safeRepayParams is record [
  amount                : nat;
  qToken                : address;
]

type safeLiquidateParams is record [
  borrower              : address;
  amount                : nat;
  qToken                : address;
]

type liquidateMiddleParams is record [
  user                  : address;
  qToken                : address;
  redeemTokens          : nat;
  borrowAmount          : nat;
]

type ensuredLiquidateParams is record [
  user                  : address;
  qToken                : address;
  redeemTokens          : nat;
  borrowAmount          : nat;
]

type useAction is 
  | UpdatePrice of updateParams
  | SetOracle of setOracleParams
  | Register of registerParams
  | UpdateQToken of updateQTokenParams
  | EnterMarket of address
  | ExitMarket of address
  // | GetUserLiquidity of getUserLiquidityParams
  // | SafeMint of safeMintParams
  // | SafeRedeem of safeRedeemParams
  // | RedeemMiddle of redeemMiddleParams
  // | EnsuredRedeem of ensuredRedeemParams
  // | SafeBorrow of safeBorrowParams
  // | BorrowMiddle of borrowMiddleParams
  // | EnsuredBorrow of ensuredBorrowParams
  // | SafeRepay of safeRepayParams
  // | SafeLiquidate of safeLiquidateParams
  // | LiquidateMiddle of liquidateMiddleParams
  // | EnsuredLiquidate of ensuredLiquidateParams

[@inline] const noOperations : list (operation) = nil
type return is list (operation) * controllerStorage
type useFunc is (useAction  * address * controllerStorage) -> return

type setUseParams is record [
  index  : nat;
  func   : useFunc;
]

type fullControllerStorage is record [
  storage     : controllerStorage;
  useLambdas  : big_map(nat, useFunc);
]

type fullReturn is list (operation) * fullControllerStorage

type entryAction is 
  | Use of useAction
  | SetUseAction of setUseParams
  | SetFactory of address
