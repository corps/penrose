const fs = require('fs');
const path = require('path');

// Read package.json of roger and core
const rogerPkg = JSON.parse(fs.readFileSync('packages/roger/package.json', 'utf8'));
const corePkg = JSON.parse(fs.readFileSync('packages/core/package.json', 'utf8'));

// Collect all dependencies
const allDeps = new Set();
const workspaceDeps = new Set();

function addDeps(pkg, name) {
  if (pkg.dependencies) {
    for (const [dep, version] of Object.entries(pkg.dependencies)) {
      if (dep.startsWith('@penrose/')) {
        workspaceDeps.add(dep);
      } else {
        allDeps.add(dep);
      }
    }
  }
  if (pkg.devDependencies) {
    for (const [dep, version] of Object.entries(pkg.devDependencies)) {
      if (dep.startsWith('@penrose/')) {
        workspaceDeps.add(dep);
      }
    }
  }
}

addDeps(rogerPkg, '@penrose/roger');
addDeps(corePkg, '@penrose/core');

// Now we need to trace transitive dependencies
// For now, just print what we have
console.log('Direct workspace deps:', [...workspaceDeps].sort());
console.log('Direct external deps:', [...allDeps].sort());
