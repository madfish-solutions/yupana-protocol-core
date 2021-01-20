var qToken = artifacts.require("qToken");

module.exports = function(deployer) {
  // deployment steps
  deployer.deploy(qToken);
};
