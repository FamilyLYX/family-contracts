import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

import "solidity-docgen";

const config: HardhatUserConfig = {
  solidity: "0.8.19",
  docgen: {
    pages: 'files',
    pageExtension: '.md'
  }
};

export default config;
