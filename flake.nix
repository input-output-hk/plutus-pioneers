{
  description = "Plutus Pioneers";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
    utils.url = "github:kreisys/flake-utils";
    cardano-node.url = "github:input-output-hk/cardano-node/1.33.0";
    plutus-apps.url = "github:input-output-hk/plutus-apps/flake-expose";
  };
  outputs = { self, nixpkgs, utils, cardano-node, plutus-apps, ... }@inputs: let
    overlay = import ./overlay.nix { inherit inputs self; };
  in utils.lib.simpleFlake {
    inherit nixpkgs overlay;
    systems = [ "x86_64-linux" "x86_64-darwin" ];
    packages = { hello }: {
      inherit hello;
      defaultPackage = hello;
    };

    shell = { devShell }: devShell;
  };
}
