type borrows is record [
    amount           : nat;
    lastBorrowIndex  : nat;
    allowances       : map (address, nat);
]

type tokenStorage is record [
    owner           : address;
    admin           : address;
    token           : address;
    lastUpdateTime  : timestamp;
    totalBorrows    : nat;
    totalLiquid     : nat;
    totalSupply     : nat;
    totalReserves   : nat;
    borrowIndex     : nat;
    accountBorrows  : big_map(address, borrows);
    accountTokens   : big_map(address, nat);
]

type return is list (operation) * tokenStorage
[@inline] const noOperations : list (operation) = nil;

type transferParams is michelson_pair(address, "from", michelson_pair(address, "to", nat, "value"), "")
type transferType is TransferOuttside of michelson_pair(address, "from", michelson_pair(address, "to", nat, "value"), "")
type approveParams is michelson_pair(address, "spender", nat, "value")
type balanceParams is michelson_pair(address, "owner", contract(nat), "")
type allowanceParams is michelson_pair(michelson_pair(address, "owner", address, "spender"), "", contract(nat), "")
type totalSupplyParams is (unit * contract(nat))

type liquidateParams is record [
  liquidator       : address;
  borrower         : address;
  amount           : nat;
]

type mintParams is record [
  user             : address;
  amount           : nat;
]

type redeemParams is record [
  user             : address;
  amount           : nat;
]

type borrowParams is record [
  user             : address;
  amount           : nat;
]

type repayParams is record [
  user             : address;
  amount           : nat;
]

type seizeParams is record [
  liquidator       : address;
  borrower         : address;
  amount           : nat;
]

// CONTROLLER PARAMS START
type membershipParams is record [
  borrowerToken         : address;
  collateralToken       : address;
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
// CONTROLLERS PARAMS END

type useAction is
  | SetAdmin of address
  | SetOwner of address
  | Mint of mintParams
  | Redeem of redeemParams
  | Borrow of borrowParams
  | Repay of repayParams
  | Liquidate of liquidateParams
  | Seize of seizeParams
  | UpdateControllerState of address

type tokenAction is
  | ITransfer of transferParams
  | IApprove of approveParams
  | IGetBalance of balanceParams
  | IGetAllowance of allowanceParams
  | IGetTotalSupply of totalSupplyParams

type entryAction is
  | Transfer of transferParams
  | Approve of approveParams
  | GetBalance of balanceParams
  | GetAllowance of allowanceParams
  | GetTotalSupply of totalSupplyParams
  | Use of useAction

type useControllerAction is 
  | UpdatePrice of updateParams
  | SetOracle of setOracleParams
  | Register of registerParams
  | UpdateQToken of updateQTokenParams
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

type useFunc is (useAction * tokenStorage * address) -> return
type tokenFunc is (tokenAction * tokenStorage) -> return
const accuracy : nat = 1000000000000000000n; //1e+18

type useParam is useAction
type useControllerParam is useControllerAction

type fullTokenStorage is record [
  storage            : tokenStorage;
  tokenLambdas       : big_map(nat, tokenFunc);
  useLambdas         : big_map(nat, useFunc);
]

type fullReturn is list (operation) * fullTokenStorage
