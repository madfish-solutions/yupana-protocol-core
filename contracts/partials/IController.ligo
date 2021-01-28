type market is record [
  collateralFactor    : nat;
  lastPrice           : nat;
  oracle              : address;
  exchangeRate        : nat;
]

type controllerStorage is record [
    factory               :address;
    admin                 :address;
    qTokens               :set(address);
    pairs                 :big_map(address, nat);
    accountBorrows        :big_map((address * address), nat);
    accountTokens         :big_map((address * address), nat);
    markets               :market;
    accountMembership     :big_map(address, address);
]

type useAction is 
  | UpdatePrice of updateParams
  | SetOracle of setOracleParams
  | Register of registerParams
  | UpdateQToken of updateQTokenParams
  | EnterMarket of enterMarketParams
  | ExitMarket of exitMarketParams
  | GetUserLiquidity of getUserLiquidityParams
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


type return is list (operation) * controllerStorage
type useFunc is (useAction * controllerStorage * address) -> return

type setUseParams is record [
  index  : nat;
  func   : useFunc;
]

type fullControllerStorage is record [
  storage     : controllerStorage;
  useLambdas  : big_map(nat, useFunc);
]

type entryAction is 
  | Use of useAction
  | SetUseAction of setUseParams
