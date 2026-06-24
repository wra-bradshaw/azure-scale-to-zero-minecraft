{
  pkgs,
  nixMinecraftLib,
  paperPackage,
  repository,
  minecraftManaged ? { },
  minecraftPlugins ? { },
}:

let
  lib = pkgs.lib;
  runtimePath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.file
    pkgs.gawk
    pkgs.gettext
    pkgs.gnugrep
    pkgs.jdk25_headless
    pkgs.rclone
  ];

  configFormats =
    let
      keyValue = pkgs.formats.keyValue { };
      txt = {
        generate =
          name: value:
          pkgs.writeText name (if builtins.isList value then lib.concatLines value else toString value);
      };
    in
    {
      ini = pkgs.formats.ini { };
      json = pkgs.formats.json { };
      properties = keyValue;
      props = keyValue;
      toml = pkgs.formats.toml { };
      txt = txt;
      yaml = pkgs.formats.yaml { };
      yml = pkgs.formats.yaml { };
    };

  formatForPath =
    path:
    let
      parts = lib.splitString "." path;
      ext = lib.last parts;
    in
    configFormats.${ext}
      or (throw "No inferred Minecraft config format for ${path}; provide a store path instead");

  materializeManagedEntry =
    path: source:
    if builtins.isAttrs source && source ? value then
      (source.format or formatForPath path).generate (baseNameOf path) source.value
    else
      source;

  materializeManagedEntries = lib.mapAttrs materializeManagedEntry;

  defaultMinecraftSymlinks = lib.mapAttrs' (
    name: drv: lib.nameValuePair "plugins/${name}" drv
  ) minecraftPlugins;
  defaultMinecraftFiles = nixMinecraftLib.collectFiles ../server/managed;

  managedSymlinks = materializeManagedEntries (
    defaultMinecraftSymlinks // (minecraftManaged.symlinks or { })
  );
  managedFiles = materializeManagedEntries (defaultMinecraftFiles // (minecraftManaged.files or { }));

  managedManifest = pkgs.writeText "minecraft-managed-manifest" (
    lib.concatStringsSep "\n" (lib.attrNames managedSymlinks ++ lib.attrNames managedFiles)
  );

  writeManagedList =
    name: entries:
    pkgs.writeText name (
      lib.concatStringsSep "\n" (lib.mapAttrsToList (path: source: "${path}\t${toString source}") entries)
    );

  managedSymlinksFile = writeManagedList "minecraft-managed-symlinks.tsv" managedSymlinks;
  managedFilesFile = writeManagedList "minecraft-managed-files.tsv" managedFiles;

  root = pkgs.runCommand "minecraft-root" { } ''
    mkdir -p "$out/opt/minecraft/managed"
    cp ${paperPackage}/lib/minecraft/server.jar "$out/opt/minecraft/server.jar"
    cp ${../server/scripts/entrypoint.sh} "$out/opt/minecraft/entrypoint.sh"
    cp ${managedManifest} "$out/opt/minecraft/managed/manifest"
    cp ${managedSymlinksFile} "$out/opt/minecraft/managed/symlinks.tsv"
    cp ${managedFilesFile} "$out/opt/minecraft/managed/files.tsv"
    chmod +x "$out"/opt/minecraft/*.sh
  '';

  image = pkgs.dockerTools.buildLayeredImage {
    name = "ghcr.io/${repository}/minecraft";
    tag = "dev";
    contents = [
      pkgs.bash
      pkgs.coreutils
      pkgs.file
      pkgs.gawk
      pkgs.gettext
      pkgs.gnugrep
      pkgs.jdk25_headless
      pkgs.rclone
      root
    ];
    config = {
      Cmd = [
        "${pkgs.bash}/bin/bash"
        "/opt/minecraft/entrypoint.sh"
      ];
      Env = [
        "MC_DATA_DIR=/srv/minecraft"
        "PATH=${runtimePath}"
      ];
      WorkingDir = "/srv/minecraft";
    };
  };
in

{
  inherit image root;
}
