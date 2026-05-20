const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Get all packages in node_modules
function getNodeModulesDirs(baseDir = 'node_modules') {
  const dirs = [];
  if (!fs.existsSync(baseDir)) return dirs;
  
  for (const item of fs.readdirSync(baseDir)) {
    const fullPath = path.join(baseDir, item);
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      if (item.startsWith('@')) {
        // Scoped package
        for (const subItem of fs.readdirSync(fullPath)) {
          const subPath = path.join(fullPath, subItem);
          if (fs.statSync(subPath).isDirectory()) {
            dirs.push(`${item}/${subItem}`);
          }
        }
      } else {
        dirs.push(item);
      }
    }
  }
  return dirs;
}

// Get the full dependency list from yarn
function getYarnList() {
  try {
    const output = execSync('yarn list --json --depth=0 2>/dev/null', {
      cwd: process.cwd(),
      encoding: 'utf8',
      maxBuffer: 1024 * 1024 * 100
    });
    return JSON.parse(output);
  } catch (e) {
    console.error('Failed to get yarn list:', e.message);
    return null;
  }
}

// For now, let's just list all top-level dirs in node_modules
const allDirs = getNodeModulesDirs();
console.log(`Total packages in node_modules: ${allDirs.length}`);
console.log('First 20:', allDirs.slice(0, 20).sort());

// Read roger's package.json to get direct deps
const rogerPkg = JSON.parse(fs.readFileSync('packages/roger/package.json', 'utf8'));
const corePkg = JSON.parse(fs.readFileSync('packages/core/package.json', 'utf8'));

const directDeps = new Set();
if (rogerPkg.dependencies) {
  for (const dep of Object.keys(rogerPkg.dependencies)) {
    directDeps.add(dep);
  }
}
if (corePkg.dependencies) {
  for (const dep of Object.keys(corePkg.dependencies)) {
    directDeps.add(dep);
  }
}

console.log('\nDirect deps:', [...directDeps].sort());
