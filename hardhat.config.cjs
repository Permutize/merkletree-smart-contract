require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    base: {
      url: "",
      accounts: [``]
    },
  },
  solidity: "0.8.28",
};
