const { MichelsonMap } = require("@taquito/michelson-encoder");
const { bob } = require("../scripts/sandbox/accounts");

module.exports = {
  account_info: MichelsonMap.fromLiteral({}),
  token_info: MichelsonMap.fromLiteral({}),
  metadata: MichelsonMap.fromLiteral({}),
  token_metadata: MichelsonMap.fromLiteral({}),
  minters: [],
  non_transferable: [],
  admin: bob.pkh,
  pending_admin: bob.pkh,
  last_token_id: "0",
}
