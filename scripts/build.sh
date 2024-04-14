mkdir -p ./flat_contracts

npx hardhat flatten contracts/AssetPlaceholder.sol > ./flat_contracts/AssetPlaceholder.sol
npx hardhat flatten contracts/OrderExtension.sol > ./flat_contracts/OrderExtension.sol
npx hardhat flatten contracts/IdentifiablePhygitalAsset.sol > ./flat_contracts/IdentifiablePhygitalAsset.sol
npx hardhat flatten contracts/AssetRegistry.sol > ./flat_contracts/AssetRegistry.sol
npx hardhat flatten contracts/UncappedFamilyAsset.sol > ./flat_contracts/UncappedFamilyAsset.sol
npx hardhat flatten contracts/GenesisPhygitalAsset.sol > ./flat_contracts/GenesisPhygitalAsset.sol
npx hardhat flatten contracts/GenesisPerk.sol > ./flat_contracts/GenesisPerk.sol
npx hardhat flatten contracts/Pass.sol > ./flat_contracts/Pass.sol

node scripts/fix_flatten.js