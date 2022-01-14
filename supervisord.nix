{ stateDir ? "./state-plutus-pioneers"
, lib
, stdenv
, writeText
, writeScriptBin
, coreutils
, lighttpd
, plutus-apps
, cardano-node
, symlinkJoin
, linkFarm
, minica
, python3 }:
let
  mkSupervisor = lib.generators.toINI {};
  supervisorConfig = writeText "supervisor.conf" (mkSupervisor ({
    supervisord = {
      logfile = "${stateDir}/supervisord.log";
      pidfile = "${stateDir}/supervisord.pid";
    };
    supervisorctl = {};
    inet_http_server = {
      port = "127.0.0.1:9001";
    };
    "rpcinterface:supervisor" = {
      "supervisor.rpcinterface_factory" = "supervisor.rpcinterface:make_main_rpcinterface";
    };
    "program:playground-client" = let

      plutusDocs = plutus-apps.packages.x86_64-linux.docs.site;
      client = plutus-apps.packages.x86_64-linux.plutus-playground.client;
      docs = linkFarm plutusDocs.name [{ name = "doc"; path = plutusDocs; }];
      webroot = symlinkJoin {
        name = "plutus-playground-client-and-docs";
        paths = [ client docs ];
      };
      lighttpdConfig = writeText "lighttpd.conf" ''
        server.modules = ("mod_deflate", "mod_openssl", "mod_proxy")
        server.document-root = "${webroot}"
        server.upload-dirs = ("/tmp")
        server.port = 8009
        ssl.engine = "enable"
        ssl.privkey = "${stateDir}/ssl/localhost/key.pem"
        ssl.pemfile = "${stateDir}/ssl/localhost/cert.pem"
        ssl.openssl.ssl-conf-cmd = ("MinProtocol" => "TLSv1.2")
        index-file.names = ("index.html")
        mimetype.assign = (
          ".css"  => "text/css",
          ".jpg"  => "image/jpeg",
          ".jpeg" => "image/jpeg",
          ".html" => "text/html",
          ".js"   => "text/javascript",
          ".svg"  => "image/svg+xml",
        )
        deflate.cache-dir = "/tmp"
        deflate.mimetypes = ("text/plain", "text/html", "text/css")
        $HTTP["url"] =~ "^/api/" {
          proxy.server = (
              "" => ( (
                  "host" => "localhost",
                  "port" => 8080
              ) )
          )
        }
      '';
      webServer = let
        pkgInputs = [ minica coreutils lighttpd ];
        in writeScriptBin "web-server" ''
        #!${stdenv.shell}
        set -euo pipefail
        export PATH=${lib.makeBinPath pkgInputs}
        mkdir -p ${stateDir}/ssl
        pushd ${stateDir}/ssl
        rm -rf localhost
        minica -ca-cert cert.pem -ca-key key.pem -domains localhost
        popd
        exec -a lighttpd lighttpd -f ${lighttpdConfig} -D
      '';
    in {
      command = "${webServer}/bin/web-server";
      environment = lib.concatStringsSep "," [
        "PATH=${minica}/bin"
      ];
      stdout_logfile = "${stateDir}/playground-client.stdout";
      stderr_logfile = "${stateDir}/playground-client.stderr";
    };
    "program:playground-server" = let
      ghcWithPackages = plutus-apps.packages.x86_64-linux.plutus-apps.haskell.project.ghcWithPackages (ps: [ ps.plutus-core ps.plutus-tx ps.plutus-contract ps.plutus-ledger ps.playground-common ]);
    in {
      command = "${plutus-apps.packages.x86_64-linux.plutus-apps.haskell.packages.plutus-playground-server.components.exes.plutus-playground-server}/bin/plutus-playground-server webserver";
      environment = lib.concatStringsSep "," [
        "WEBGHC_URL=http://localhost:8080"
        "FRONTEND_URL=https://localhost:8009"
        "PATH=${ghcWithPackages}/bin"
        "GITHUB_CALLBACK_PATH=https://localhost:8009/api/oauth/github/callback"
        "PORT=8080"
      ];
      stdout_logfile = "${stateDir}/playground-server.stdout";
      stderr_logfile = "${stateDir}/playground-server.stderr";
    };
    "program:node-testnet" = {
      command = ''${cardano-node.packages.x86_64-linux."testnet/node"}/bin/cardano-node-testnet'';
      stdout_logfile = "${stateDir}/node-testnet.stdout";
      stderr_logfile = "${stateDir}/node-testnet.stderr";
      stopsignal = "INT";
    };
  }));
  start = writeScriptBin "start" ''
    set -euo pipefail
    if [ ! -d ${stateDir} ]
    then
      echo "Creating state directory for supervisord"
      mkdir -p ${stateDir}
    fi
    if [ -f ${stateDir}/supervisord.pid ]
    then
      echo "Services already running. Please run `stop` first!"
    fi
    ${python3.pkgs.supervisor}/bin/supervisord --config ${supervisorConfig} $@
  '';
  stop = writeScriptBin "stop" ''
    set -euo pipefail
    ${python3.pkgs.supervisor}/bin/supervisorctl stop all
    if [ -f ${stateDir}/supervisord.pid ]
    then
      kill $(<${stateDir}/supervisord.pid)
      echo "Services terminated!"
    else
      echo "Services are not running!"
    fi
  '';
  healthcheck = writeScriptBin "healthcheck" ''
    set -euo pipefail
    echo TODO: make this really healthcheck
    exit 0
  '';

in {
  inherit start stop healthcheck;
}
