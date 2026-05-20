const fs = require('fs');
const path = require('path');

// Read all package.json files in node_modules and build a dependency graph
function buildDepGraph(baseDir = 'node_modules') {
  const graph = {};
  const packages = {}; // name -> {path, package.json}
  
  function scanDir(dir) {
    if (!fs.existsSync(dir)) return;
    
    for (const item of fs.readdirSync(dir)) {
      const fullPath = path.join(dir, item);
      const stat = fs.statSync(fullPath);
      
      if (stat.isDirectory()) {
        const pkgPath = path.join(fullPath, 'package.json');
        if (fs.existsSync(pkgPath)) {
          try {
            const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
            const name = pkg.name;
            if (!name) continue;
            
            packages[name] = {
              path: fullPath,
              pkg: pkg,
              dependencies: Object.keys(pkg.dependencies || {}),
              devDependencies: Object.keys(pkg.devDependencies || {})
            };
            
            graph[name] = {
              deps: [...packages[name].dependencies],
              path: fullPath
            };
          } catch (e) {
            // console.error(`Error reading ${pkgPath}:`, e.message);
          }
        }
        
        // Recurse into @scoped packages
        if (item.startsWith('@')) {
          scanDir(fullPath);
        }
      }
    }
  }
  
  scanDir(baseDir);
  return { graph, packages };
}

// Trace all dependencies starting from a set of packages
function traceDependencies(startDeps, graph) {
  const allDeps = new Set(startDeps);
  const toProcess = [...startDeps];
  
  while (toProcess.length > 0) {
    const pkg = toProcess.pop();
    const info = graph[pkg];
    
    if (!info) {
      // console.warn(`Package ${pkg} not found in graph`);
      continue;
    }
    
    for (const dep of info.deps) {
      if (!allDeps.has(dep)) {
        allDeps.add(dep);
        toProcess.push(dep);
      }
    }
  }
  
  return allDeps;
}

// Main
const { graph, packages } = buildDepGraph();

// Direct dependencies of roger and core
const directDeps = new Set([
  '@penrose/core',
  'canvas',
  'chalk',
  'chokidar',
  'convert-hrtime',
  'global-jsdom',
  'jsdom',
  'node-fetch',
  'prettier',
  'regenerator-runtime',
  'true-myth',
  'ws',
  'yargs',
  '@datastructures-js/queue',
  'consola',
  'immutable',
  'lodash',
  'mathjax-full',
  'ml-matrix',
  'moo',
  'nearley',
  'pandemonium',
  'poly-partition',
  'recursive-diff',
  'rose',
  'seedrandom'
]);

const allDeps = traceDependencies([...directDeps], graph);
console.log([...allDeps].sort().join('\n'));
