const fs = require('fs');
const path = require('path');

function walk(dir, fileList = []) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const stat = fs.statSync(path.join(dir, file));
    if (stat.isDirectory()) {
      walk(path.join(dir, file), fileList);
    } else if (file.endsWith('.dart')) {
      fileList.push(path.join(dir, file));
    }
  }
  return fileList;
}

const dirs = [
  'c:\\Hansuke\\Work\\abo_glumbo_bkk\\lib',
  'c:\\Hansuke\\Work\\abo_glumbo_technician_bbk\\lib'
];

const results = [];
// Regex to match Text('something') or Text("something")
// Simplistic: Text\(\s*(['"])(.*?)\1
const regex = /Text\(\s*(['"])(.*?)\1/g;

for (const dir of dirs) {
  if (fs.existsSync(dir)) {
    const files = walk(dir);
    for (const file of files) {
      const content = fs.readFileSync(file, 'utf8');
      let match;
      while ((match = regex.exec(content)) !== null) {
        const text = match[2];
        if (!text.includes('AppLocalizations') && !text.includes('$') && text.trim().length > 0) {
           results.push(file + ': ' + text);
        }
      }
    }
  }
}

fs.writeFileSync('texts_found.txt', results.join('\n'));
console.log('Found ' + results.length + ' strings.');
