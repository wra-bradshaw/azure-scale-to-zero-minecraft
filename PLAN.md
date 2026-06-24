# Scale-To-Zero Minecraft Server Plan

## Summary

Production runs on Azure Container Apps.

- `gate` is the always-on public TCP proxy.
- `waiting` is an internal PicoLimbo backend.
- `minecraft` is an internal Paper server with `min_replicas = 0` and Azure Files mounted at `/srv/minecraft`.
- Gate routes status and join traffic to the waiting backend while Paper is cold, triggers an Azure Container Apps wake, polls Minecraft status, then transfers waiting players once Paper is healthy.
- Local development still uses Docker Compose and `SCALER_MODE=local`.

Gate plugins are compiled into a custom Gate binary, not loaded dynamically. That matches Gate's documented model and works well with Nix.

## Repo Structure

- `infra/terraform/` contains the Terraform Cloud backend config, Azure Container Apps production module, and Cloudflare DNS record.
- `packages/gate-scale-plugin/` contains the custom Gate entrypoint and scaler plugin.
- `packages/minecraft-runtime-plugin/` contains the Paper idle shutdown plugin.
- `images/` contains Nix Docker image definitions.
- `server/` contains Minecraft entrypoint scripts and managed config templates.
- `.github/workflows/` contains CI, image, and Terraform workflows.
- `Justfile` contains local commands around Nix, Terraform, image build/push, and development.

## Gate Plugin Design

Production configuration comes from environment variables:

- `SCALER_MODE=azure`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_RESOURCE_GROUP`
- `AZURE_CONTAINER_APP_NAME=minecraft`
- `AZURE_CONTAINER_APP_ENVIRONMENT`
- `MC_SERVER_NAME=minecraft`
- `WAITING_SERVER_NAME=waiting`
- `MC_HOST=minecraft`
- `MC_PORT=25565`
- `WAITING_HOST=waiting`
- `WAITING_PORT=25565`
- `WAKE_TIMEOUT`
- `WAKE_POLL_INTERVAL`
- `TRANSFER_RETRY_INTERVAL`

Gate config:

- Use full proxy mode, not Lite mode.
- `servers.waiting = waiting:25565`
- `servers.minecraft = minecraft:25565`
- `try = ["waiting"]`
- Gate API can remain disabled unless needed for debugging.

Plugin behavior:

- On `PlayerChooseInitialServerEvent`, route to `minecraft` if healthy, otherwise route to `waiting` and trigger wake.
- Keep a small in-memory state machine for `idle`, `starting`, `ready`, and `failed`.
- Ensure many players joining at once trigger only one wake request.
- Wake flow opens the internal Minecraft TCP service to trigger Container Apps scale-from-zero, optionally verifies/nudges the Container App through Azure ARM using managed identity, and polls Minecraft status ping until ready or timeout.
- Once Minecraft is ready, transfer all players currently on `waiting` to `minecraft` using Gate's native connection request API.
- Retry transient transfer failures with bounded backoff.
- On timeout or failure, leave players in PicoLimbo and allow a future wake attempt after cooldown.

## Azure Production Infrastructure

Terraform provisions durable infrastructure only:

- Azure Resource Group.
- VNet and delegated subnet for Azure Container Apps external TCP ingress.
- Azure Container Apps managed environment.
- Azure Files share registered as Container Apps environment storage.
- Container Apps:
  - `gate`: public TCP ingress on `25565`, system-assigned managed identity, `min_replicas = 1`.
  - `waiting`: internal TCP ingress on `25565`, `min_replicas = 1`.
  - `minecraft`: internal TCP ingress on `25565`, `min_replicas = 0`, `max_replicas = 1`, Azure Files at `/srv/minecraft`.
- Cloudflare CNAME pointing the Minecraft domain at the gate app FQDN.

Terraform must not run player-triggered start/stop and must not deploy per connection.

## Minecraft Runtime

The Minecraft image runs Paper with Java 21 and the runtime plugin.

- World data, server config, allowlist, ops, logs, and plugin runtime data live under `/srv/minecraft`.
- Managed config and plugins are applied on container start.
- The Paper plugin watches idle player count.
- After zero players for `SHUTDOWN_GRACE_SECONDS`, it saves worlds and calls `Bukkit.shutdown()`.
- Azure Container Apps scales the Minecraft app to zero after TCP connections drain and scale cooldown elapses.

## Nix And Images

Nix builds Docker images for:

- Custom Gate binary with embedded scale plugin.
- PicoLimbo waiting room.
- Minecraft server.

Use GHCR as the image registry. Tag images with both commit SHA and a stable environment tag.

## Test Plan

Plugin unit tests:

- Offline Minecraft sends player to waiting.
- Healthy Minecraft sends player to Minecraft.
- Multiple joins trigger only one wake.
- Readiness success transfers all waiting players.
- Readiness timeout leaves players in waiting.
- Transfer failure retries and logs.
- Azure scaler covers SDK-backed management status, wake nudge payloads, and error paths.

Local integration:

- Run Docker Compose with the three Nix-built images.
- Verify Gate listens on `localhost:25565`.
- Verify local mode does not call Azure.

Infra validation:

- `terraform fmt -check -recursive`
- `terraform validate`
- `tflint`
- `nix flake check`
- Build `gate-scale-image`, `picolimbo-image`, and `minecraft-image`.

Azure proof of concept before cutover:

- Deploy a minimal internal TCP app with `min_replicas = 0`.
- Confirm a gate-side TCP connection wakes it.
- Confirm cold-start time is acceptable.
- Confirm scale-to-zero occurs after idle cooldown.
- Confirm Azure Files persists writes across scale-to-zero.
