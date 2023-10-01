// eslint-disable-next-line @typescript-eslint/no-var-requires
const fs = require('fs');

let files = [
  './flat_contracts/AssetPlaceholder.sol',
  './flat_contracts/AssetRegistry.sol',
  './flat_contracts/IdentifiablePhygitalAsset.sol',
  './flat_contracts/OrderExtension.sol'
];

files.map((file) => {
  fs.readFile(file, 'utf8', (err, data) => {
    if (err) {
      console.error(err);
    }
  
    // create an array of lines
    let lines = data.split('\n').slice(0);
  
    let removeDuplicates = (substr, lines) => {
      let substrCount = 0;
      let result = lines.map((line, index, content) => {
        if (String(line).match(substr)) {
          substrCount++;
          if (substrCount > 1) content.splice(index, 1);
        }
        return content;
      });
      return result;
    };
  
    removeDuplicates(/^\/\/\WSPDX-License-Identifier/, lines);
    removeDuplicates(/^pragma/, lines);
  
    data = lines.join('\n');
  
    fs.writeFile(file, data, (err) => {
      err | console.log('Duplicate pragma and SPDX statements removed successfully !');
    });
  });
});
