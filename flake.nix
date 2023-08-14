{
  description = "bdfr-browser development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Tools

    flake-parts.url = "github:hercules-ci/flake-parts";

    flake-root.url = "github:srid/flake-root";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks-nix = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.gitignore.follows = "gitignore";
    };

    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
  };

  outputs = inputs@{ flake-parts, gitignore, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];

      imports = [
        inputs.flake-root.flakeModule
        inputs.treefmt-nix.flakeModule
        inputs.pre-commit-hooks-nix.flakeModule
        inputs.process-compose-flake.flakeModule
      ];

      perSystem = { pkgs, lib, config, self', ... }:
        let
          pname = "bdfr-browser";
          version = "0.0.1";

          erlang = pkgs.beam.interpreters.erlangR26;
          beamPackagesPrev = pkgs.beam.packagesWith erlang;
          elixir = beamPackagesPrev.elixir_1_15;

          beamPackages = beamPackagesPrev // rec {
            inherit erlang elixir;
            hex = beamPackagesPrev.hex.override { inherit elixir; };
            buildMix = beamPackagesPrev.buildMix.override { inherit elixir erlang hex; };
            mixRelease = beamPackagesPrev.mixRelease.override { inherit erlang elixir; };
          };

          postgres = pkgs.postgresql_15;

          inherit (pkgs.stdenv) isDarwin;
          inherit (pkgs.stdenv) isLinux;
          inherit (gitignore.lib) gitignoreSource;
        in
        {
          treefmt = {
            inherit (config.flake-root) projectRootFile;
            flakeCheck = false;

            programs = {
              mix-format = {
                enable = true;
                package = elixir;
              };

              nixpkgs-fmt.enable = true;
            };
          };

          pre-commit = {
            check.enable = false;

            settings = {
              excludes = [ "mix.nix" ];

              hooks = {
                deadnix.enable = true;
                statix.enable = true;
                treefmt.enable = true;
              };
            };
          };

          devShells.default = pkgs.mkShell {
            name = pname;

            nativeBuildInputs = [
              erlang
              elixir
              postgres
            ] ++ lib.optionals isDarwin (with pkgs.darwin.apple_sdk.frameworks; [
              CoreFoundation
              CoreServices
            ]) ++ lib.optionals isLinux (with pkgs; [
              inotify-tools
            ]);

            packages = [
              pkgs.mix2nix
              self'.packages.bdfr-browser-dev
            ];

            inputsFrom = [
              config.flake-root.devShell
              config.treefmt.build.devShell
              config.pre-commit.devShell
            ];

            ERL_INCLUDE_PATH = "${erlang}/lib/erlang/usr/include";
            TREEFMT_CONFIG_FILE = config.treefmt.build.configFile;
          };

          packages.default = beamPackages.mixRelease {
            inherit pname version;

            buildInputs = [ ] ++ lib.optionals isDarwin (with pkgs.darwin.apple_sdk.frameworks; [
              CoreFoundation
              CoreServices
            ]) ++ lib.optionals isLinux (with pkgs; [
              inotify-tools
            ]);

            src = gitignoreSource ./.;
            mixNixDeps = import ./mix.nix { inherit lib beamPackages; };
          };

          process-compose."${pname}-dev" =
            let
              db-host = "127.0.0.1";
              db-user = "bdfr-browser";
            in
            {
              port = 18808;

              settings = {
                environment = {
                  BDFR_BROWSER_BASE_DIRECTORY = "/Volumes/MediaScraper/Reddit";
                  BDFR_BROWSER_REPO_USER = db-user;
                  BDFR_BROWSER_REPO_HOST = db-host;
                  RELEASE_DISTRIBUTION = "none";
                  RELEASE_COOKIE = "no_dist_anyway";
                };

                processes = {
                  db-init.command = ''
                    if [ ! -d "$PWD/.direnv/postgres/data" ]; then
                      echo "Initializing database ..."
                      mkdir -p "$PWD/.direnv/postgres"
                      ${postgres}/bin/initdb --username ${db-user} --pgdata "$PWD/.direnv/postgres/data" --auth trust
                    else
                      echo "Database already initialized"
                    fi
                  '';

                  db = {
                    command = "${postgres}/bin/postgres -D $PWD/.direnv/postgres/data";

                    depends_on.db-init.condition = "process_completed_successfully";

                    readiness_probe.exec.command = "PGCONNECT_TIMEOUT=1 ${postgres}/bin/psql -h ${db-host} -U ${db-user} -l";
                  };

                  app-setup.command = ''
                    mix local.hex --if-missing --force
                    mix local.rebar --force
                    mix deps.get
                  '';

                  app-compile = {
                    command = "mix release --overwrite";

                    depends_on.app-setup.condition = "process_completed_successfully";
                  };

                  app = {
                    command = "$PWD/_build/dev/rel/bdfr_browser/bin/bdfr_browser start";

                    depends_on = {
                      db.condition = "process_healthy";
                      app-compile.condition = "process_completed_successfully";
                    };

                    readiness_probe.http_get = {
                      host = "127.0.0.1";
                      port = 4040;
                      path = "/_ping";
                    };
                  };
                };
              };
            };
        };
    };
}
