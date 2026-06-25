{
  pkgs,
  nixMinecraftLib,
  paperPackage,
  picolimboPackage ? null,
  minecraftManaged ? { },
  minecraftPlugins ? { },
}:

let
  repository = let value = builtins.getEnv "GITHUB_REPOSITORY"; in if value == "" then "local/mc-server" else value;

  gateScale = import ./gate-scale.nix {
    inherit pkgs repository;
  };

  picolimbo = import ./picolimbo.nix {
    inherit pkgs picolimboPackage repository;
  };

  minecraftRuntimePlugin = import ../packages/minecraft-runtime-plugin { inherit pkgs; };
  viaVersion = pkgs.fetchurl {
    url = "https://cdn.modrinth.com/data/P1OZGk5p/versions/z0sCGSmk/ViaVersion-5.10.1-SNAPSHOT.jar";
    hash = "sha512-v0TfoWe1ii/O9OQKhx82WOytoB9m3U/SekHY9ehFUnng7wrG9kV84cwdGYH8RYwCNC7Cc6fCBHieK+ssQVbUpg==";
  };
  veinminer = pkgs.fetchurl {
    url = "https://cdn.modrinth.com/data/OhduvhIc/versions/FZvBlAqk/veinminer-paper-2.10.4.jar";
    hash = "sha512-yFjiaOakEMfi0emq6KLD4hF6F/rAjqpQfW8T3Nu+CAwMF5/0J8mdcJKe3Cp2TGq0SYXhMK7DovmKGc1kJYhmrw==";
  };

  minecraft = import ./minecraft.nix {
    inherit
      pkgs
      nixMinecraftLib
      paperPackage
      repository
      minecraftManaged
      ;
    minecraftPlugins = {
      "McServerRuntime.jar" = "${minecraftRuntimePlugin}/McServerRuntime.jar";
      "ViaVersion.jar" = viaVersion;
      "Veinminer.jar" = veinminer;
    } // minecraftPlugins;
  };
in

{
  gate-scale = gateScale.package;
  gate-scale-image = gateScale.image;

  picolimbo = picolimbo.package;
  picolimbo-image = picolimbo.image;

  minecraft-image = minecraft.image;
  minecraft-runtime-plugin = minecraftRuntimePlugin;
}
