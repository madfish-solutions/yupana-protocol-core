const { dev, alice } = require("../scripts/sandbox/accounts");
const { migrate, getDeployedAddress } = require("../scripts/helpers");
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

const yStorage = {
  admin: dev.pkh,
  ledger: MichelsonMap.fromLiteral({}),
  accounts: MichelsonMap.fromLiteral({}),
  tokens: MichelsonMap.fromLiteral({}),
  lastTokenId: "0",
  priceFeedProxy: alice.pkh,
  closeFactorF: "0",
  liqIncentiveF: "0",
  markets: MichelsonMap.fromLiteral({}),
  borrows: MichelsonMap.fromLiteral({}),
  maxMarkets: "0",
  assets: MichelsonMap.fromLiteral({}),
};
let contractAddress = 0;

module.exports = async (tezos) => {
  contractAddress = await migrate(tezos, "yToken", {
    storage: yStorage,
    metadata: metadata,
    token_metadata: MichelsonMap.fromLiteral({}),
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

  const interestAddress = getDeployedAddress("interestRate");
  const contract = await tezos.contract.at(contractAddress);

  const interest2Address = await migrate(tezos, "interestRate", {
    admin: dev.pkh,
    kinkF: "800000000000000000",
    baseRateF: "634195839",
    multiplierF: "7134703196",
    jumpMultiplierF: "31709791983",
    reserveFactorF: "0",
    lastUpdTime: "2021-08-20T09:06:50Z",
  });
  console.log(`InterestRate2 contract: ${interest2Address}`);

  const priceFeedAddress = getDeployedAddress("priceFeed");
  let priceFeedContract = await tezos.contract.at(priceFeedAddress);
  let op = await priceFeedContract.methods.updateYToken(contractAddress).send();
  await confirmOperation(tezos, op.hash);

  const fa12ContractAddress = "KT1LnLf5piuiLNY2J3Y81XiFm6dCpprZrwSh";
  const fa2ContractAddress = "KT1W6bLbCgkQSLA1G9YcbJwYGphcYTHPCgsi";
  const tokenMetadata = MichelsonMap.fromLiteral({
    symbol: Buffer.from("TXTZ").toString("hex"),
    name: Buffer.from("TXTZtoken").toString("hex"),
    decimals: Buffer.from("6").toString("hex"),
    is_transferable: Buffer.from("true").toString("hex"),
    is_boolean_amount: Buffer.from("false").toString("hex"),
    should_prefer_symbol: Buffer.from("false").toString("hex"),
    thumbnailUri: Buffer.from("ipfs://QmRjdJtosqYqHaC8PXUYLZEe2PRi42cTwoVbn1gGj2NoM9").toString("hex"),
  });
  const tokenMetadata2 = MichelsonMap.fromLiteral({
    symbol: Buffer.from("TBTC").toString("hex"),
    name: Buffer.from("TBTCtoken").toString("hex"),
    decimals: Buffer.from("8").toString("hex"),
    is_transferable: Buffer.from("true").toString("hex"),
    is_boolean_amount: Buffer.from("false").toString("hex"),
    should_prefer_symbol: Buffer.from("false").toString("hex"),
    thumbnailUri: Buffer.from("ipfs://QmQxmFng1X5KhLHEgNKZh5f2Da146jBC5tjw3sYnyfd2yS").toString("hex"),
  });

  let contract = await tezos.contract.at(contractAddress);

  op = await contract.methods
    .setGlobalFactors(
      500000000000000000,
      1050000000000000000,
      priceFeedAddress,
      10
    )
    .send();
  await confirmOperation(tezos, op.hash);

  op = await contract.methods
    .addMarket(
      interestAddress,
      "fA12",
      fa12ContractAddress,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata,
      550000000000000000
    )
    .send();
  await confirmOperation(tezos, op.hash);

  op = await contract.methods
    .addMarket(
      interest2Address,
      "fA2",
      fa2ContractAddress,
      0,
      750000000000000000,
      150000000000000000,
      5000000000000,
      tokenMetadata2,
      550000000000000000
    )
    .send();
  await confirmOperation(tezos, op.hash);
};
