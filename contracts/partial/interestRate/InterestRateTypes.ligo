type rateStorage        is [@layout:comb] record [
  admin                 : address;
  yToken                : address;
  kickRateFloat         : nat;
  baseRateFloat         : nat;
  multiplierFloat       : nat;
  jumpMultiplierFloat   : nat;
  reserveFactorFloat    : nat;
  lastUpdTime           : timestamp;
]

type setCoeffParams     is [@layout:comb] record [
  kickRateFloat         : nat;
  baseRateFloat         : nat;
  multiplierFloat       : nat;
  jumpMultiplierFloat   : nat;
]

type rateParams         is [@layout:comb] record [
  tokenId               : nat;
  borrowsFloat          : nat;
  cashFloat             : nat;
  reservesFloat         : nat;
  precision              : nat;
  contract              : contract(yAssetParams);
]
