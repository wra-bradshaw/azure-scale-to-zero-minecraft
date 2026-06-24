# Images

Nix is the image build source of truth.

- `gate-scale`: custom Gate binary with the embedded scaler plugin.
- `picolimbo`: waiting-room backend built from PicoLimbo `v1.13.1+mc26.2`.
- `minecraft`: nix-minecraft `paper-server` with Java 21, the runtime Paper plugin, managed plugins/config, and volume-backed data.

Minecraft managed paths are declared in `images/images.nix` through:

- `minecraftPlugins`: attrset of fixed-output plugin jar derivations, linked under `/srv/minecraft/plugins`.
- `minecraftManaged.symlinks`: attrset of server-relative paths to immutable store targets.
- `minecraftManaged.files`: attrset of server-relative paths to copied writable files or directories.

On container start, `/opt/minecraft/managed` is applied to `/srv/minecraft`: previously managed paths are removed, newly managed paths replace existing files after moving them to `.bak`, symlinks are recreated, and copied text files receive environment substitution. Paths not listed in `.nix-minecraft-managed`, such as worlds and plugin runtime data directories, remain mutable.

The Minecraft container does not hold cloud-provider credentials and does not power off a host directly. In production, the runtime Paper plugin saves worlds and exits Paper after the configured idle grace period; Azure Container Apps then scales the Minecraft app to zero after TCP connections drain and the scale cooldown elapses.

Flake package outputs:

- `gate-scale-image`
- `picolimbo-image`
- `minecraft-image`
- `minecraft-runtime-plugin`

Local full-stack development uses Docker Compose with the same Nix-built image tags as production:

- `just dev-up`: build/load the three Linux images and run Gate on `localhost:25565`.
- `just dev-down`: stop the local stack.
- `just dev-reset`: remove local Minecraft data under `.local/minecraft`.
- `just dev-logs SERVICE`: tail logs for `gate`, `minecraft`, or `picolimbo`.

The local stack sets `SCALER_MODE=local`, so Gate does not call Azure. Local Docker Compose keeps Minecraft running until the container is stopped.

By default local image loading targets `aarch64-linux`, which matches Docker Desktop on Apple Silicon. Set `LOCAL_DOCKER_SYSTEM=x86_64-linux` to load amd64 images instead.
