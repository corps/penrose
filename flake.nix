{
  description = "Create beautiful diagrams just by typing notation in plain text";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        nodejs = pkgs.nodejs_18;
        yarnConfigHook' = pkgs.yarnConfigHook.override {
          yarn = pkgs.yarn.override { inherit nodejs; };
        };
      in
      {
        packages = {
          default = pkgs.stdenv.mkDerivation (finalAttrs: {
            pname = "penrose";
            version = "3.3.0";

            src = ./.;

            yarnOfflineCache = pkgs.fetchYarnDeps {
              yarnLock = finalAttrs.src + "/yarn.lock";
              hash = "sha256-z0+3gSvvtCm14IPfzSa1mlHtJfCeL7BFBPEEn926Ej4=";
            };

            nativeBuildInputs = [
              yarnConfigHook'
              nodejs
              pkgs.pkg-config
              (pkgs.python3.withPackages (ps: [ ps.setuptools ]))
              pkgs.makeWrapper
            ];

            buildInputs = [
              pkgs.cairo
              pkgs.giflib
              pkgs.libpng
              pkgs.librsvg
              pkgs.pango
              pkgs.pixman
            ];

            buildPhase = ''
              runHook preBuild

              export PATH="$PWD/node_modules/.bin:$PATH"

              # Point node-gyp at the nodejs headers so it doesn't try to download them
              export npm_config_nodedir=${nodejs}

              # Rebuild only the canvas native addon — yarnConfigHook uses --ignore-scripts
              # (other native addons like farmhash aren't needed for roger and have
              # node-gyp compatibility issues with newer Python)
              echo 'canvas'
              npm rebuild canvas --verbose

              echo 'nearleyc'
              cd packages/core
              nearleyc src/parser/Domain.ne > src/parser/DomainParser.ts
              nearleyc src/parser/Substance.ne > src/parser/SubstanceParser.ts
              nearleyc src/parser/Style.ne > src/parser/StyleParser.ts

              echo 'tsc'
              tsc
              cd ../roger
              tsc
              # cd ../components
              # rm -rf src/stories
              # rm src/editing/TimelineTable.tsx
              # npm run build-parsers
              # npm run build
              cd ../..

              echo 'done here'

              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              # Copy node_modules (contains compiled canvas native addon)
              mkdir -p $out/lib
              cp -r node_modules "$out/lib/node_modules"

              # Remove all workspace symlinks (they point to packages/ dirs we didn't copy)
              for link in "$out/lib/node_modules/@penrose"/*; do
                if [ -L "$link" ]; then
                  rm "$link"
                fi
              done
              # Also remove any other top-level workspace symlinks
              for link in "$out/lib/node_modules/penrose-vs" \
                          "$out/lib/node_modules/penrose"*; do
                if [ -L "$link" ]; then
                  rm "$link"
                fi
              done

              # Now re-add the three parts we care about.
              local rogerOut="$out/lib/node_modules/@penrose/roger"
              # local componentsOut="$out/lib/node_modules/@penrose/components"
              local coreOut="$out/lib/node_modules/@penrose/core"

              mkdir -p "$rogerOut"
              ln -s $out/lib/node_modules $rogerOut/node_modules
              # mkdir -p "$componentsOut"
              # ln -s $out/lib/node_modules $componentsOut/node_modules
              mkdir -p "$coreOut"
              ln -s $out/lib/node_modules $coreOut/node_modules

              cp -r packages/roger/dist "$rogerOut/dist"
              cp -r packages/roger/bin "$rogerOut/bin"
              cp packages/roger/package.json "$rogerOut/package.json"

              # cp -r packages/components/dist "$componentsOut/dist"
              # cp packages/components/package.json "$componentsOut/package.json"

              cp -r packages/core/dist "$coreOut/dist"
              cp packages/core/package.json "$coreOut/package.json"


              find "$out/lib/node_modules/.bin" -xtype l -delete 2>/dev/null || true

              mkdir -p "$out/bin"
              makeWrapper ${nodejs}/bin/node "$out/bin/roger" --add-flags "$rogerOut/bin/run.js"

              runHook postInstall
            '';
          });
        };

        devShell =
          with pkgs;
          mkShell {
            buildInputs = [
              cairo
              giflib
              libpng
              librsvg
              nixfmt-rfc-style
              pango
              pixman
              pkg-config
              python310
              (yarn.override { nodejs = nodejs_18; })
            ];
          };
      }
    );
}
