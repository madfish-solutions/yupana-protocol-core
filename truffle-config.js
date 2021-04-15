const { accounts } = require('./scripts/sandbox/accounts');
const { accountsMap } = require('./scripts/sandbox/accounts');

module.exports = {
  // see <http://truffleframework.com/docs/advanced/configuration>
  // for more details on how to specify configuration options!
  // development: {
  //   host: "http://136.244.96.28",
  //   port: 8732,
  //   network_id: "*",
  //   secretKey: accountsMap.get(accounts[0]),
  //   type: "tezos"
  // },
  contracts_directory: "./contracts/main",
  networks: {
    development: {
      host: "http://localhost",
      port: 8732,
      network_id: "*",
      secretKey: accountsMap.get(accounts[0]),
      type: "tezos",
    },
    development_server: {
      host: "http://136.244.96.28",
      port: 8732,
      network_id: "*",
      secretKey: accountsMap.get(accounts[0]),
      type: "tezos"
    },
    florencenet: {
      host: "https://florencenet.smartpy.io",
      port: 443,
      network_id: "*",
      secretKey: accountsMap.get(accounts[11]),
      type: "tezos",
    },
    edonet: {
      host: "https://edonet.smartpy.io",
      port: 443,
      network_id: "*",
      secretKey: accountsMap.get(accounts[10]),
      type: "tezos",
    },
    delphinet: {
      host: "https://delphinet.smartpy.io",
      port: 443,
      network_id: "*",
      secretKey: accountsMap.get(accounts[10]),
      type: "tezos",
    },
    mainnet: {
      host: "https://mainnet.smartpy.io",
      port: 443,
      network_id: "*",
      type: "tezos",
    },
  }
};
