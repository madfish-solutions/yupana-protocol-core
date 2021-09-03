const { MichelsonMap } = require("@taquito/michelson-encoder");
const { alice } = require("../scripts/sandbox/accounts");

module.exports = {
  account_info: MichelsonMap.fromLiteral({}),
  token_info: MichelsonMap.fromLiteral({}),
  metadata: MichelsonMap.fromLiteral({}),
  token_metadata: MichelsonMap.fromLiteral({}),
  minters: [],
  non_transferable: [],
  tokens_ids: [],
  admin: alice.pkh,
  pending_admin: alice.pkh,
  last_token_id: "0",
}
