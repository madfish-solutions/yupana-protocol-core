require("dotenv").config();

const { alice, dev } = require("./scripts/sandbox/accounts");

module.exports = {
  outputFile: "output.txt",
  confirmationPollingTimeoutSecond: 2000000,
  syncInterval: 0, // 0 for tests, 5000 for deploying
  confirmTimeout: 90000, // 90000 for tests, 180000 for deploying
  buildDir: "build",
  migrationsDir: "migrations",
  contractsDir: "contracts/main",
  ligoVersion: "0.20.0",
  network: "development",
  networks: {
    development: {
      rpc: "http://localhost:8732",
      network_id: "*",
      secretKey: alice.sk,
    },
    development_server: {
      host: "http://136.244.96.28",
      port: 8732,
      network_id: "*",
      secretKey: alice.pkh,
    },
    granadanet: {
      rpc: "https://granadanet.smartpy.io",
      port: 443,
      network_id: "*",
      secretKey: dev.sk,
    },
    mainnet: {
      host: "https://mainnet.smartpy.io",
      port: 443,
      network_id: "*",
      secretKey: alice.pkh,
    },
  },
};
