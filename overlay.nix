final: prev:
let
  lib = final.lib;
  supervisorScripts = final.callPackage ./supervisord.nix { inherit (final) plutus cardano; };
in {
  inherit (supervisorScripts) start stop;
  devShell = prev.mkShell rec {
    nativeBuildInputs = with final; [
      start
      stop
      python3Packages.supervisor
      coreutils
      cardano.cli
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
