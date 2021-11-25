const { dev, alice } = require("../scripts/sandbox/accounts");
const { migrate } = require("../scripts/helpers");
const { MichelsonMap } = require("@taquito/michelson-encoder");
const { confirmOperation } = require("../scripts/confirmation");
const { functions } = require("../storage/functions");
const { getLigo } = require("../scripts/helpers");
const { execSync } = require("child_process");
const { InMemorySigner } = require("@taquito/signer");

const metadata = MichelsonMap.fromLiteral({
  "": Buffer.from("tezos-storage:yupana", "ascii").toString("hex"),
  yupana: Buffer.from(
    JSON.stringify({
      name: "Yupana",
      version: "v1.0.0",
      description: "Yupana protocol.",
      authors: ["madfish.solutions"],
      source: {
        tools: ["Ligo", "Flextesa"],
        location: "https://ligolang.org/",
      },
      homepage: "https://yupana.com",
      interfaces: ["TZIP-12", "TZIP-16"],
      errors: [],
      views: [],
    }),
    "ascii"
  ).toString("hex"),
});

const tokenStorage = {
  admin: dev.pkh,
  ledger: MichelsonMap.fromLiteral({}),
  accounts: MichelsonMap.fromLiteral({}),
  tokens: MichelsonMap.fromLiteral({}),
  metadata: metadata,
  tokenMetadata: MichelsonMap.fromLiteral({}),
  lastTokenId: "0",
  priceFeedProxy: alice.pkh,
  closeFactorF: "0",
  liqIncentiveF: "0",
  markets: MichelsonMap.fromLiteral({}),
  borrows: MichelsonMap.fromLiteral({}),
  maxMarkets: "0",
  assets: MichelsonMap.fromLiteral({}),
  threshold: "0",
};
let contractAddress = 0;
module.exports = async (tezos) => {
  contractAddress = await migrate(tezos, "yToken", {
    storage: tokenStorage,
    tokenLambdas: MichelsonMap.fromLiteral({}),
    useLambdas: MichelsonMap.fromLiteral({}),
  });

  tezos.setProvider({
    signer: await InMemorySigner.fromSecretKey(dev.sk),
  });

  const ligo = getLigo(true);
  let params = [];

  console.log("Start setting Token lambdas");
  for (const yTokenFunction of functions.token) {
    const stdout = execSync(
      `${ligo} compile-expression pascaligo --michelson-format=json --init-file $PWD/contracts/main/yToken.ligo 'SetTokenAction(record [index = ${yTokenFunction.index}n; func = Bytes.pack(${yTokenFunction.name})] )'`,
      { maxBuffer: 1024 * 1000 }
    );

    const input_params = JSON.parse(stdout.toString());

    params.push({
      kind: "transaction",
      to: contractAddress,
      amount: 0,
      parameter: {
        entrypoint: "setTokenAction",
        value: input_params.args[0].args[0].args[0].args[0], // TODO get rid of this mess
      },
    });
  }

  console.log("Start setting yToken lambdas");

  for (yTokenFunction of functions.yToken) {
    const stdout = execSync(
      `${ligo} compile-expression pascaligo --michelson-format=json --init-file $PWD/contracts/main/yToken.ligo 'SetUseAction(record [index = ${yTokenFunction.index}n; func = Bytes.pack(${yTokenFunction.name})] )'`,
      { maxBuffer: 1024 * 1000 }
    );
    const input_params = JSON.parse(stdout.toString());

    params.push({
      kind: "transaction",
      to: contractAddress,
      amount: 0,
      parameter: {
        entrypoint: "setUseAction",
        value: input_params.args[0].args[0].args[0].args[0], // TODO get rid of this mess
      },
    });
  }
  const batch = tezos.wallet.batch(params);
  const operation1 = await batch.send();

  await confirmOperation(tezos, operation1.opHash);
  console.log("Setting finished");

  console.log(`YToken contract: ${contractAddress}`);
};
