type rateStorage        is [@layout:comb] record [
  admin                 : address;
  kinkF                 : nat;
  baseRateF             : nat;
  multiplierF           : nat;
  jumpMultiplierF       : nat;
  reserveFactorF        : nat;
  lastUpdTime           : timestamp;
  utilLambda            : bytes;
]

type utilRateParams     is [@layout:comb] record [
  borrowsF              : nat;
  cashF                 : nat;
  reservesF             : nat;
  precision             : nat;
]

type rateLambda         is utilRateParams -> nat

type setCoeffParams     is [@layout:comb] record [
  kinkF                 : nat;
  baseRateF             : nat;
  multiplierF           : nat;
  jumpMultiplierF       : nat;
]

type rateParams         is [@layout:comb] record [
  tokenId               : nat;
  borrowsF              : nat;
  cashF                 : nat;
  reservesF             : nat;
  precision             : nat;
  reserveFactorF        : nat;
  callback              : contract(yAssetParams);
]
