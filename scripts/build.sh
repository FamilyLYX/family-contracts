mkdir -p ./flat_contracts

npx hardhat flatten contracts/AssetPlaceholder.sol > ./flat_contracts/AssetPlaceholder.sol
npx hardhat flatten contracts/OrderExtension.sol > ./flat_contracts/OrderExtension.sol
npx hardhat flatten contracts/IdentifiablePhygitalAsset.sol > ./flat_contracts/IdentifiablePhygitalAsset.sol
npx hardhat flatten contracts/AssetRegistry.sol > ./flat_contracts/AssetRegistry.sol
node scripts/fix_flatten.js