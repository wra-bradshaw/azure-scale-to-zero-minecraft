set dotenv-load
LOCAL_DOCKER_SYSTEM := env_var_or_default("LOCAL_DOCKER_SYSTEM", "aarch64-linux")

default:
    just --list

fmt:
    gofmt -w packages/gate-scale-plugin
    terraform -chdir=infra fmt -recursive

dev-image-load IMAGE:
    docker load < "$(nix build --print-out-paths ".#packages.{{LOCAL_DOCKER_SYSTEM}}.{{IMAGE}}-image")"

dev-images:
    just dev-image-load gate-scale
    just dev-image-load picolimbo
    just dev-image-load minecraft

dev-up: dev-images
    docker compose -f docker-compose.local.yml up

dev-down:
    docker compose -f docker-compose.local.yml down

dev-reset: dev-down
    rm -rf .local/minecraft

dev-logs SERVICE:
    docker compose -f docker-compose.local.yml logs -f {{SERVICE}}
