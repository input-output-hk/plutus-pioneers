{
  description = "Plutus Pioneers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
    utils.url   = "github:kreisys/flake-utils";
    cardano.url = "github:input-output-hk/cardano-node/1.33.0";
    plutus.url  = "github:input-output-hk/plutus-apps/flake-expose";
  };

  outputs = { self, nixpkgs, utils, cardano, plutus, ... }@inputs: let
    dependencies = final: prev: {
      plutus = {
        docs                = plutus.packages.${final.system}.docs.site;
        playground-client   = plutus.packages.${final.system}.plutus-playground.client;
        playground-server   = plutus.packages.${final.system}.plutus-apps.haskell.packages.plutus-playground-server.components.exes.plutus-playground-server;
        ghc                 = plutus.packages.${final.system}.plutus-apps.haskell.project.ghcWithPackages (ps: [ ps.plutus-core ps.plutus-tx ps.plutus-contract ps.plutus-ledger ps.playground-common ]);
      };

      cardano = {
        cli          = cardano.packages.${final.system}.cardano-cli;
        testnet-node = cardano.packages.${final.system}."testnet/node";
      };
    };
  in utils.lib.simpleFlake {
    inherit nixpkgs;
    overlay     = import ./overlay.nix;
    preOverlays = [ dependencies ];
    systems     = [ "x86_64-linux" "x86_64-darwin" ];
    shell       = { devShell }: devShell;

    packages = { hello }: {
      inherit hello;
      defaultPackage = hello;
    };
  };
}
