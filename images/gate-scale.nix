{
  pkgs,
  repository,
}:

let
  runtimePath = pkgs.lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.gettext
    root
  ];

  package = pkgs.buildGoModule {
    pname = "gate-scale";
    version = "0.1.0";
    src = ../packages/gate-scale-plugin;
    vendorHash = "sha256-+PmaWYdOkVGxbFGWVmW0GjlA7jF4KPbA4st5/LovdTk=";
    proxyVendor = true;
    subPackages = [ "cmd/gate-scale" ];
  };

  root = pkgs.runCommand "gate-scale-root" { } ''
    mkdir -p "$out/bin" "$out/opt/gate"
    cp ${package}/bin/gate-scale "$out/bin/gate-scale"
    cp ${../packages/gate-scale-plugin/config/config.yml} "$out/opt/gate/config.yml.template"
    cp ${../packages/gate-scale-plugin/config/entrypoint.sh} "$out/bin/gate-entrypoint"
    substituteInPlace "$out/bin/gate-entrypoint" \
      --replace-fail 'exec /bin/gate-scale' 'exec '"$out"'/bin/gate-scale'
    chmod +x "$out/bin/gate-scale" "$out/bin/gate-entrypoint"
  '';

  image = pkgs.dockerTools.buildLayeredImage {
    name = "ghcr.io/${repository}/gate-scale";
    tag = "dev";
    contents = [
      pkgs.bash
      pkgs.cacert
      pkgs.coreutils
      pkgs.gettext
      root
    ];
    config = {
      Entrypoint = [
        "${pkgs.bash}/bin/bash"
        "${root}/bin/gate-entrypoint"
      ];
      Env = [ "PATH=${runtimePath}" ];
      ExposedPorts = {
        "25565/tcp" = { };
      };
    };
  };
in

{
  inherit image package root;
}
