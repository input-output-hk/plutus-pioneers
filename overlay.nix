{ inputs, self }:
final: prev:
let
  lib = final.lib;
  supervisorScripts = final.callPackage ./supervisord.nix { inherit (inputs) plutus-apps cardano-node; };
in {
  inherit (supervisorScripts) start stop;
  devShell = prev.mkShell rec {
    nativeBuildInputs = with final; [
      start
      stop
      python3Packages.supervisor
      coreutils
      inputs.cardano-node.packages.x86_64-linux.cardano-cli
    ];
    shellHook = ''
      echo "Plutus Pioneers Shell Tools" \
      | ${final.figlet}/bin/figlet -f banner -c \
      | ${final.lolcat}/bin/lolcat

      export CARDANO_NODE_SOCKET_PATH=./state-node-testnet/node.socket

      cat << EOF
      Commands:
            start: start playground
            stop: stop playground
      EOF
    '';
    };
}
