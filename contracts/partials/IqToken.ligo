type borrows is
  record [
    amount           :nat;
    lastBorrowIndex  :nat;
    allowances       :map (address, nat);
  ]

type storage is
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

type return is list (operation) * storage
[@inline] const noOperations : list (operation) = nil;

type transferParams is michelson_pair(address, "from", michelson_pair(address, "to", nat, "value"), "")
type transferType is TransferOuttside of michelson_pair(address, "from", michelson_pair(address, "to", nat, "value"), "")
type approveParams is michelson_pair(address, "spender", nat, "value")
type balanceParams is michelson_pair(address, "owner", contract(nat), "")
type allowanceParams is michelson_pair(michelson_pair(address, "owner", address, "spender"), "", contract(nat), "")
type totalSupplyParams is (unit * contract(nat))

type mintParams is michelson_pair(address, "user", nat, "amount")
type redeemParams is michelson_pair(address, "user", nat, "amount")
type borrowParams is michelson_pair(address, "user", nat, "amount")
type repayParams is michelson_pair(address, "user", nat, "amount")
type liquidateParams is michelson_pair(address, "liquidator", michelson_pair(address, "borrower", nat, "amount"), "")

type entryAction is
  | Transfer of transferParams
  | Approve of approveParams
  | GetBalance of balanceParams
  | GetAllowance of allowanceParams
  | GetTotalSupply of totalSupplyParams
  | SetAdmin of address
  | SetOwner of address
  | Mint of mintParams
  | Redeem of redeemParams
  | Borrow of borrowParams
  | Repay of repayParams
  | Liquidate of liquidateParams
