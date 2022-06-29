type rateStorage        is [@layout:comb] record [
  admin                 : address;
  kinkF                 : nat;
  baseRateF             : nat;
  multiplierF           : nat;
  jumpMultiplierF       : nat;
  reserveFactorF        : nat;
  metadata              : big_map(string, bytes);
]

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
