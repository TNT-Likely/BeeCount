// Read the same ISC-licensed Lucide definitions used by the HTML prototype.
// Default: check only. --write adds missing assets without rewriting existing SVGs.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const vendor = path.join(root, 'docs/design/card-refresh/prototype/vendor/lucide.min.js');
const definitions = require(vendor).icons;
const assetRoot = path.join(root, 'packages/beecount_ui/assets/icons');
const registryPath = path.join(__dirname, 'lucide-icon-names.json');
const write = process.argv.includes('--write');
const references = new Map();
function scan(directory) {
  for (const item of fs.readdirSync(directory, {withFileTypes: true})) {
    const file = path.join(directory, item.name);
    if (item.isDirectory()) {
      if (item.name !== 'l10n') scan(file);
    } else if (item.isFile() && file.endsWith('.dart') && !file.endsWith('.g.dart')) {
      const source = fs.readFileSync(file, 'utf8');
      for (const match of source.matchAll(/['"]([A-Z][A-Za-z0-9]+)['"]/g)) {
        const name = match[1];
        if (!definitions[name]) continue;
        if (!references.has(name)) references.set(name, new Set());
        references.get(name).add(path.relative(root, file));
      }
    }
  }
}
for (const directory of ['lib', 'packages/beecount_ui/lib', 'packages/beecount_business_ui/lib']) {
  scan(path.join(root, directory));
}
const missing = [...references.keys()].filter(name => !fs.existsSync(path.join(assetRoot, name + '.svg'))).sort();
const escape = value => String(value).replaceAll('&', '&amp;').replaceAll('"', '&quot;');
if (write) {
  for (const name of missing) {
    const children = definitions[name].map(([tag, attributes]) =>
      `<${tag} ${Object.entries(attributes).map(([key, value]) => `${key}="${escape(value)}"`).join(' ')}/>`).join('');
    fs.writeFileSync(path.join(assetRoot, name + '.svg'),
      `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#262829" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${children}</svg>\n`);
  }
  fs.writeFileSync(registryPath, JSON.stringify({
    vendorSha256: crypto.createHash('sha256').update(fs.readFileSync(vendor)).digest('hex'),
    names: Object.keys(definitions).sort()
  }, null, 2) + '\n');
}
console.log(JSON.stringify({status: missing.length && !write ? 'FAIL' : 'PASS', required: references.size,
  missingBeforeWrite: missing.map(name => ({name, sources: [...references.get(name)]})), added: write ? missing : []}));
if (missing.length && !write) process.exitCode = 1;
