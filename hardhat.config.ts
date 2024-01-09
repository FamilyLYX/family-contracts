import { HardhatUserConfig } from "hardhat/config";
import { config as LoadEnv } from 'dotenv';
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ethers"

LoadEnv();

import "solidity-docgen";
import "hardhat-contract-sizer";
// import { hexlify } from "@ethersproject/bytes";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [{
      version: "0.8.20",
      settings: {
        optimizer: {
          enabled: true,
          runs: 100
        },
      }
    }, {
      version: "0.8.19",
      settings: {
        optimizer: {
          enabled: true,
          runs: 100
        },
      },
    }]
  },
  networks: {
    luksoTestnet: {
      url: 'https://rpc.testnet.lukso.gateway.fm',
      chainId: 4201,
      accounts: [process.env.PRIVATE_KEY as string],
    },
    luksoMainnet: {
      url: 'https://rpc.lukso.gateway.fm',
      chainId: 42,
      accounts: [process.env.PRIVATE_KEY as string],
    },
  },
  docgen: {
    pages: 'files',
    pageExtension: '.md'
  }
};

export default config;
