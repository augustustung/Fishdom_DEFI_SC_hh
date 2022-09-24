const fs = require('fs');
const path = require('path');

function saveDeployments(pathToFile, data) {
  const resolvedPathToFile = path.resolve(__filename, `../../artifacts/contracts${pathToFile}`);
  let compliedContract = fs.readFileSync(resolvedPathToFile, { encoding: 'utf-8' });
  compliedContract = JSON.parse(compliedContract);
  compliedContract = JSON.stringify({
    ...compliedContract,
    ...data
  });
  fs.writeFileSync(resolvedPathToFile, compliedContract);
}

module.exports = saveDeployments;