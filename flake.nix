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
          roger = pkgs.stdenv.mkDerivation (finalAttrs: {
            pname = "roger";
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
              npm rebuild canvas --verbose

              # Generate nearley parsers for @penrose/core
              cd packages/core
              nearleyc src/parser/Domain.ne > src/parser/DomainParser.ts
              nearleyc src/parser/Substance.ne > src/parser/SubstanceParser.ts
              nearleyc src/parser/Style.ne > src/parser/StyleParser.ts

              # Build core (tsc), then roger (tsc)
              tsc
              cd ../roger
              tsc
              cd ../..

              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              local packageOut="$out/lib/node_modules/@penrose/roger"
              mkdir -p "$packageOut"

              # Copy roger package
              cp -r packages/roger/dist "$packageOut/dist"
              cp -r packages/roger/bin "$packageOut/bin"
              cp packages/roger/package.json "$packageOut/package.json"

              # Copy node_modules (contains compiled canvas native addon)
              cp -r node_modules "$packageOut/node_modules"

              # Remove all workspace symlinks (they point to packages/ dirs we didn't copy)
              for link in "$packageOut/node_modules/@penrose"/*; do
                if [ -L "$link" ]; then
                  rm "$link"
                fi
              done
              # Also remove any other top-level workspace symlinks
              for link in "$packageOut/node_modules/penrose-vs" \
                          "$packageOut/node_modules/penrose"*; do
                if [ -L "$link" ]; then
                  rm "$link"
                fi
              done

              # Remove broken symlinks in .bin
              find "$packageOut/node_modules/.bin" -xtype l -delete 2>/dev/null || true

              # Install the workspace packages roger actually needs
              mkdir -p "$packageOut/node_modules/@penrose/core"
              cp packages/core/package.json "$packageOut/node_modules/@penrose/core/"
              cp -r packages/core/dist "$packageOut/node_modules/@penrose/core/"

              # Create bin wrapper
              mkdir -p "$out/bin"
              makeWrapper ${nodejs}/bin/node "$out/bin/roger" \
                --add-flags "$packageOut/bin/run.js"

              runHook postInstall
            '';
          });

          default = self.packages.${system}.roger;
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
