type rateStorage        is [@layout:comb] record [
  admin                 : address;
  yToken                : address;
  kickRate              : nat;
  baseRate              : nat;
  multiplier            : nat;
  jumpMultiplier        : nat;
  reserveFactor         : nat;
]

type setCoeffParams     is record [
  kickRate              : nat;
  baseRate              : nat;
  multiplier            : nat;
  jumpMultiplier        : nat;
]

type rateParams         is record [
  tokenId               : nat;
  borrows               : nat;
  cash                  : nat;
  reserves              : nat;
  contract              : contract(tokenId * nat);
]

type supplyRateParams   is record [
  tokenId               : nat;
  borrows               : nat;
  cash                  : nat;
  reserves              : nat;
  contract              : contract(tokenId * nat);
]

