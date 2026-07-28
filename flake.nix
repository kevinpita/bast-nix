{
  description = "Nix flake for Bast, a terminal SSH host picker, key manager, and CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      overlay = final: prev: {
        bast = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachSystem systems (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.bast;
          bast = pkgs.bast;
        };

        apps = {
          default = {
            type = "app";
            program = "${pkgs.bast}/bin/bast";
          };
          bast = {
            type = "app";
            program = "${pkgs.bast}/bin/bast";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            gh
            jq
            nixpkgs-fmt
          ];
        };
      }
    )
    // {
      overlays.default = overlay;
    };
}
