const { alice } = require("../scripts/sandbox/accounts");
require("dotenv").config();

const { execSync } = require("child_process");
const fs = require("fs");
const { TezosToolkit } = require("@taquito/taquito");
const { InMemorySigner } = require("@taquito/signer");
const { confirmOperation } = require("./confirmation");
const { functions } = require("../storage/functions");
const env = require("../env");

const getLigo = (isDockerizedLigo) => {
  let path = "ligo";

  if (isDockerizedLigo) {
    path = `docker run -v $PWD:$PWD --rm -i ligolang/ligo:${env.ligoVersion}`;

    try {
      execSync(`${path}  --help`);
    } catch (err) {
      path = "ligo";

      execSync(`${path}  --help`);
    }
  } else {
    try {
      execSync(`${path}  --help`);
    } catch (err) {
      path = `docker run -v $PWD:$PWD --rm -i ligolang/ligo:${env.ligoVersion}`;

      execSync(`${path}  --help`);
    }
  }

  return path;
};

const getContractsList = () => {
  return fs
    .readdirSync(env.contractsDir)
    .filter((file) => file.endsWith(".ligo"))
    .map((file) => file.slice(0, file.length - 5));
};

const getMigrationsList = () => {
  return fs
    .readdirSync(env.migrationsDir)
    .filter((file) => file.endsWith(".js"))
    .map((file) => file.slice(0, file.length - 3));
};

const compile = async (contract) => {
  const ligo = getLigo(true);
  const contracts = !contract ? getContractsList() : [contract];

  contracts.forEach((contract) => {
    const michelson = execSync(
      `${ligo} compile contract --michelson-format json $PWD/${env.contractsDir}/${contract}.ligo`,
      { maxBuffer: 1024 * 10000 }
    ).toString();

    try {
      const artifacts = JSON.stringify(
        {
          michelson: JSON.parse(michelson),
          networks: {},
          compiler: "ligo:" + env.ligoVersion,
        },
        null,
        2
      );

      if (!fs.existsSync(env.buildDir)) {
        fs.mkdirSync(env.buildDir);
      }

      fs.writeFileSync(`${env.buildDir}/${contract}.json`, artifacts);
    } catch (e) {
      console.error(michelson);
    }
  });
};

function saveLambdas(lambdas, filename) {
  const out_path = `${env.buildDir + "/lambdas"}`;

  if (!fs.existsSync(out_path)) {
    fs.mkdirSync(out_path, { recursive: true });
  }
  const save_path = `${out_path}/${filename}.json`;
  fs.writeFileSync(save_path, JSON.stringify(lambdas));
}

export const compileLambdas = async (
  type
) => {
  type = type.toLowerCase();
  try {
    const ligo = getLigo(true);
    console.log(`Compiling lambdas of ${type} type...\n`);
    if (type.toLowerCase() === "ytoken") {
      console.log("Compiling Token lambdas");
      const tokenLambdas = [];
      for (const yTokenFunction of functions.token) {
        const stdout = execSync(
          `${ligo} compile expression pascaligo --michelson-format json --init-file $PWD/contracts/main/yToken.ligo 'SetTokenAction(record [index = ${yTokenFunction.index}n; func = Bytes.pack(${yTokenFunction.name})] )'`,
          { maxBuffer: 1024 * 1000 }
        );

        const input_params = JSON.parse(stdout.toString());
        tokenLambdas.push(input_params.args[0].args[0].args[0].args[0]);
      }
      saveLambdas(tokenLambdas, "tokenLambdas");

      console.log("Compiling yToken `use` lambdas");
      const yTokenLambdas = [];
      for (yTokenFunction of functions.yToken) {
        const stdout = execSync(
          `${ligo} compile expression pascaligo --michelson-format json --init-file $PWD/contracts/main/yToken.ligo 'SetUseAction(record [index = ${yTokenFunction.index}n; func = Bytes.pack(${yTokenFunction.name})] )'`,
          { maxBuffer: 1024 * 1000 }
        );

        const input_params = JSON.parse(stdout.toString());
        yTokenLambdas.push(input_params.args[0].args[0].args[0].args[0]);
      }
      saveLambdas(yTokenLambdas, "yTokenLambdas");
    }
    if (type.toLowerCase() === "interest") {
      const stdout = execSync(
        `${ligo} compile expression pascaligo --michelson-format json --init-file $PWD/contracts/main/interestRate.ligo 'Bytes.pack(${functions.interestLambda.name})'`,
        { maxBuffer: 1024 * 1000 }
      );
      const input_params = JSON.parse(stdout.toString());
      saveLambdas(input_params, "interestLambda");
    }
  } catch (e) {
    console.error(e);
  }
};

const migrate = async (tezos, contract, storage) => {
  try {
    const artifacts = JSON.parse(
      fs.readFileSync(`${env.buildDir}/${contract}.json`)
    );
    const operation = await tezos.contract
      .originate({
        code: artifacts.michelson,
        storage: storage,
      })
      .catch((e) => {
        console.error(JSON.stringify(e));

        return { contractAddress: null };
      });

    await confirmOperation(tezos, operation.hash);

    artifacts.networks[env.network] = { [contract]: operation.contractAddress };

    if (!fs.existsSync(env.buildDir)) {
      fs.mkdirSync(env.buildDir);
    }

    fs.writeFileSync(
      `${env.buildDir}/${contract}.json`,
      JSON.stringify(artifacts, null, 2)
    );

    return operation.contractAddress;
  } catch (e) {
    console.error(e);
  }
};

const getDeployedAddress = (contract) => {
  try {
    const artifacts = JSON.parse(
      fs.readFileSync(`${env.buildDir}/${contract}.json`)
    );

    return artifacts.networks[env.network][contract];
  } catch (e) {
    console.error(e);
  }
};

const runMigrations = async (options) => {
  try {
    let migrations = getMigrationsList()
    options.network = options.network || "development";
    options.optionFrom = options.from || 0;
    options.optionTo = options.to || migrations.length;

    migrations = migrations.slice(options.optionFrom, options.optionTo + 1);

    const networkConfig = env.networks[options.network];

    const tezos = new TezosToolkit(networkConfig.rpc);

    tezos.setProvider({
      config: {
        confirmationPollingTimeoutSecond: env.confirmationPollingTimeoutSecond,
      },
      signer: await InMemorySigner.fromSecretKey(alice.sk),
    });

    for (const migration of migrations) {
      const execMigration = require(`../${env.migrationsDir}/${migration}.js`);

      await execMigration(tezos);
    }
  } catch (e) {
    console.error(e);
  }
};

module.exports = {
  getLigo,
  getContractsList,
  getMigrationsList,
  getDeployedAddress,
  compile,
  compileLambdas,
  migrate,
  runMigrations,
  env,
};
