function wrap_fa12_transfer_trx(
  const from_           : address;
  const to_             : address;
  const amt             : nat)
                        : transferType is
  TransferOutside(record [
      from_ = from_;
      to_ = to_;
      value = amt
    ])

function wrap_fa2_transfer_trx(
  const from_           : address;
  const to_             : address;
  const amt             : nat;
  const id              : nat)
                        : iterTransferType is
  IterateTransferOutside(list[
    record [
      from_ = from_;
      txs = list[
        record[
          tokenId = id;
          to_ = to_;
          amount = amt
        ]
      ]
    ]
  ])

function transfer_fa12(
  const from_           : address;
  const to_             : address;
  const amt             : nat;
  const token           : address)
                        : list(operation) is
  list[Tezos.transaction(
    wrap_fa12_transfer_trx(from_, to_, amt),
    0mutez,
    getTokenContract(token)
  )];

function transfer_fa2(
  const from_           : address;
  const to_             : address;
  const amt             : nat;
  const token           : address;
  const id              : nat)
                        : list(operation) is
  list[Tezos.transaction(
    wrap_fa2_transfer_trx(from_, to_, amt, id),
    0mutez,
    getIterTransferContract(token)
  )];

function transfer_token(
  const from_           : address;
  const to_             : address;
  const amt             : nat;
  const token           : assetType)
                        : list(operation) is
  case token of
    FA12(token) -> transfer_fa12(from_, to_, amt, token)
  | FA2(token)  -> transfer_fa2(from_, to_, amt, token.0, token.1)
  end