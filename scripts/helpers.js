const { alice } = require("../scripts/sandbox/accounts");
require("dotenv").config();
require("ts-node").register({
  files: true,
});
const { program } = require("commander");
const { exec, execSync } = require("child_process");
const fs = require("fs");
const { TezosToolkit } = require("@taquito/taquito");
const { InMemorySigner } = require("@taquito/signer");
const { confirmOperation } = require("./confirmation");
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
      `${ligo} compile-contract --michelson-format=json $PWD/${env.contractsDir}/${contract}.ligo main`,
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
    const migrations = getMigrationsList();

    options.network = options.network || "development";
    options.optionFrom = options.from || 0;
    options.optionTo = options.to || migrations.length;

    const networkConfig = env.networks[options.network];
    // const tezos = new TezosToolkit("http://136.244.96.28:8732");
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
  migrate,
  runMigrations,
  env,
};
