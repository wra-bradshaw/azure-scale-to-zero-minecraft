{
  inputs = {
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
    picolimbo.url = "github:Quozul/PicoLimbo/v1.13.1%2Bmc26.2";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      nixpkgs,
      nix-minecraft,
      picolimbo,
      systems,
      ...
    }:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      devShells = forEachSystem (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.age
              pkgs.crane
              pkgs.curl
              pkgs.dnsutils
              pkgs.file
              pkgs.gh
              pkgs.gettext
              pkgs.go
              pkgs.gopls
              pkgs.gotools
              pkgs.gnugrep
              pkgs.jdk25_headless
              pkgs.jq
              pkgs.just
              pkgs.netcat
              pkgs.opentofu
              pkgs.rclone
              pkgs.skopeo
              pkgs.sops
              pkgs.terraform
              pkgs.terraform-docs
              pkgs.terraform-ls
              pkgs.tflint
              pkgs.yq-go
            ];
          };
        }
      );

      packages = forEachSystem (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          picolimboPackage =
            if nixpkgs.lib.hasAttrByPath [ system "default" ] picolimbo.packages then
              picolimbo.packages.${system}.default
            else
              throw "PicoLimbo does not publish a package for ${system}";
          nixMinecraftPackages = nix-minecraft.legacyPackages.${system};
          images = import ./images {
            inherit pkgs picolimboPackage;
            nixMinecraftLib = nix-minecraft.lib;
            paperPackage = nixMinecraftPackages.paperServers.paper-26_1_2;
          };
        in
        {
          inherit (images)
            gate-scale
            gate-scale-image
            minecraft-image
            minecraft-runtime-plugin
            picolimbo
            picolimbo-image
            ;
          default = images.gate-scale-image;
        }
      );

      checks = forEachSystem (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          gate-scale-tests = pkgs.stdenvNoCC.mkDerivation {
            name = "gate-scale-tests";
            src = ./.;
            nativeBuildInputs = [
              pkgs.go
            ];
            dontConfigure = true;
            dontBuild = true;
            checkPhase = ''
              cd packages/gate-scale-plugin
              go test ./...
            '';
            installPhase = "mkdir -p $out";
          };
          minecraft-runtime-plugin = import ./packages/minecraft-runtime-plugin { inherit pkgs; };
          minecraft-script-tests = pkgs.stdenvNoCC.mkDerivation {
            name = "minecraft-script-tests";
            src = ./.;
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.file
              pkgs.gawk
              pkgs.gettext
              pkgs.gnugrep
              pkgs.rclone
              pkgs.ripgrep
            ];
            dontConfigure = true;
            dontBuild = true;
            checkPhase = ''
              bash server/scripts/tests.sh
            '';
            installPhase = "mkdir -p $out";
          };
        }
      );
    };
}
