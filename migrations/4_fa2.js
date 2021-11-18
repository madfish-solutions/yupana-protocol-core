const { migrate } = require("../scripts/helpers");
const { dev } = require("../scripts/sandbox/accounts");
const { MichelsonMap } = require("@taquito/michelson-encoder");

module.exports = async (tezos) => {
  const contractAddress = await migrate(tezos, "fa2", {
    totalSupplyF: "0",
    ledger: MichelsonMap.fromLiteral({}),
    account_info: MichelsonMap.fromLiteral({}),
    token_info: MichelsonMap.fromLiteral({}),
    metadata: MichelsonMap.fromLiteral({}),
    token_metadata: MichelsonMap.fromLiteral({}),
    minters: [],
    admin: dev.pkh,
    pending_admin: dev.pkh,
    last_token_id: "0",
  });

  console.log(`Fa2 contract: ${contractAddress}`);
};
