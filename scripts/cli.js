require("dotenv").config();

const yargs = require("yargs");
const { compile, compileLambdas, runMigrations } = require("./helpers");

const argv = yargs
  .command(
    "compile [contract]",
    "compiles the contract",
    {
      contract: {
        description: "the contract to compile",
        alias: "c",
        type: "string",
      },
    },
    async (argv) => compile(argv.contract)
  )
  .command(
    "compile-lambda [type]",
    "compiles lambda functions and stores to json",
    {
      type: {
        description: "Type of lambda function (interest or ytoken)",
        alias: "t",
        type: "string",
      }
    },
    async (argv) => compileLambdas(argv.type)
  )
  .command(
    "migrate [network] [from] [to]",
    "run migrations",
    {
      from: {
        description: "the migrations counter to start with",
        alias: "f",
        type: "number",
      },
      to: {
        description: "the migrations counter to end with",
        alias: "to",
        type: "number",
      },
      network: {
        description: "the network to deploy",
        alias: "n",
        type: "string",
      },
    },
    async (argv) => {
      runMigrations(argv);
    }
  )
  .help()
  .strictCommands()
  .demandCommand(1)
  .alias("help", "h").argv;
