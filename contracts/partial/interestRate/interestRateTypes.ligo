type rateStorage        is [@layout:comb] record [
  admin                 : address;
  kinkRateF             : nat;
  baseRateF             : nat;
  multiplierF           : nat;
  jumpMultiplierF       : nat;
  reserveFactorF        : nat;
  lastUpdTime           : timestamp;
]

type setCoeffParams     is [@layout:comb] record [
  kinkRateF             : nat;
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
