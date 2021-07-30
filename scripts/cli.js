require("dotenv").config();

const yargs = require("yargs");
const { compile, runMigrations } = require("./helpers");

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
    async (argv) => {
      compile(argv.contract);
    }
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
