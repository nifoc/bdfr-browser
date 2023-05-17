{
  description = "bdfr-browser development environment";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];

      perSystem = { pkgs, lib, self', ... }:
        let
          pname = "bdfr-browser";
          version = "0.0.1";

          erlang = pkgs.beam.interpreters.erlangR25;
          beamPackages = pkgs.beam.packagesWith erlang;
          elixir = beamPackages.elixir_1_14;

          inherit (pkgs.stdenv) isDarwin;
        in
        {
          devShells.default = pkgs.mkShell {
            packages = (with pkgs; [
              erlang
              elixir

              beamPackages.elixir-ls
              mix2nix
            ]) ++ lib.optionals isDarwin (with pkgs.darwin.apple_sdk.frameworks; [
              CoreFoundation
              CoreServices
            ]);

            ERL_INCLUDE_PATH = "${erlang}/lib/erlang/usr/include";
          };

          packages.default = beamPackages.mixRelease {
            inherit pname version;

            src = ./.;
            mixNixDeps = import ./mix.nix { inherit lib beamPackages; };
          };
        };
    };
}
