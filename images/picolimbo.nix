{
  pkgs,
  picolimboPackage ? null,
  repository,
}:

let
  package = if picolimboPackage != null then picolimboPackage else pkgs.picolimbo;
  runtimePath = pkgs.lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.gettext
    root
  ];

  root = pkgs.runCommand "picolimbo-root" { } ''
    mkdir -p "$out/bin" "$out/opt/picolimbo"
    cp ${package}/bin/pico_limbo "$out/bin/pico_limbo"
    cp ${./picolimbo-server.toml.template} "$out/opt/picolimbo/server.toml.template"
    cp ${./picolimbo-entrypoint.sh} "$out/bin/picolimbo-entrypoint"
    substituteInPlace "$out/bin/picolimbo-entrypoint" \
      --replace-fail 'exec /bin/pico_limbo' 'exec '"$out"'/bin/pico_limbo'
    chmod +x "$out/bin/pico_limbo" "$out/bin/picolimbo-entrypoint"
  '';

  image = pkgs.dockerTools.buildLayeredImage {
    name = "ghcr.io/${repository}/picolimbo";
    tag = "dev";
    contents = [
      pkgs.bash
      pkgs.cacert
      pkgs.coreutils
      pkgs.gettext
      root
    ];
    config = {
      Entrypoint = [ "${pkgs.bash}/bin/bash" "${root}/bin/picolimbo-entrypoint" ];
      Env = [ "PATH=${runtimePath}" ];
      ExposedPorts = { "25565/tcp" = { }; };
    };
  };
in

{
  inherit image package root;
}
