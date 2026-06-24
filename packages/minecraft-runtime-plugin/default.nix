{ pkgs }:

pkgs.maven.buildMavenPackage {
  pname = "mc-server-runtime-plugin";
  version = "0.1.0";
  src = ./.;

  mvnJdk = pkgs.jdk21_headless;
  mvnHash = "sha256-heVNUI1PxGn4eHVEYE32mEaAMGoJ+V6oblK3ucIGmE4=";

  installPhase = ''
    runHook preInstall
    install -Dm644 target/mc-server-runtime-plugin-0.1.0.jar "$out/McServerRuntime.jar"
    runHook postInstall
  '';
}
