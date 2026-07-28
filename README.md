# bast-nix

Always up-to-date Nix package for [Bast](https://github.com/ellipse-software/bast), a terminal SSH host picker, key manager, and CLI.

## Quick Start

```bash
nix run github:kevinpita/bast-nix
```

## Install

```bash
nix profile install github:kevinpita/bast-nix
```

## Use In A Flake

```nix
{
  inputs.bast-nix.url = "github:kevinpita/bast-nix";

  outputs = { bast-nix, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          bast-nix.packages.${system}.default
        ];
      };
    };
}
```

## Development

```bash
nix build .#bast
./result/bin/bast --version
```

## Updates

The update workflow checks upstream releases hourly and can also be run manually from GitHub Actions. When a new release exists, it updates `package.nix`, refreshes the fixed-output hashes, creates a pull request, and enables auto-merge.

Manual update:

```bash
./scripts/update.sh --check
./scripts/update.sh --version 0.5.0
```
