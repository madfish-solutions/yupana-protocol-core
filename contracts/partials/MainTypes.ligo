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

type transferParams is [@layout:comb] record [
  [@annot:from] from_ : address;
  [@annot:to] to_ : address;
  value : nat;
]

type transferType is TransferOutside of transferParams

type approveParams is [@layout:comb] record [
  spender : address;
  value : nat;
]

type balanceParams is [@layout:comb] record [
  owner : address;
  [@annot:] receiver : contract(nat);
]

type allowanceParams is [@layout:comb] record [
  owner : address;
  spender : address;
  [@annot:] receiver : contract(nat);
]

type totalSupplyParams is (unit * contract(nat))

type liquidateParams is record [
  liquidator       : address;
  borrower         : address;
  amount           : nat;
  collateralToken  : address;
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

// type updParams is michelson_pair(string, "string", contract(michelson_pair(string, "string", michelson_pair(timestamp, "timestamp", nat, "nat"))), "")

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

type safeBorrowParams is [@layout:comb] record [
  qToken                : address;
  amount                : nat;
  borrowerToken         : address;
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

type safeLiquidateParams is [@layout:comb] record [
  borrower              : address;
  amount                : nat;
  qToken                : address;
]

type ensuredLiquidateParams is record [
  user                  : address;
  borrower              : address;
  qToken                : address;
  redeemTokens          : nat;
  borrowAmount          : nat;
  collateralToken       : address;
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
  | EnsuredRedeem of ensuredRedeemParams
  | SafeBorrow of safeBorrowParams
  | EnsuredBorrow of ensuredBorrowParams
  | SafeRepay of safeRepayParams
  | SafeLiquidate of safeLiquidateParams
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
