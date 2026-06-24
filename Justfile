set dotenv-load
LOCAL_DOCKER_SYSTEM := env_var_or_default("LOCAL_DOCKER_SYSTEM", "aarch64-linux")

default:
    just --list

fmt:
    gofmt -w packages/gate-scale-plugin
    terraform -chdir=infra/terraform fmt -recursive

test:
    cd packages/gate-scale-plugin && GOCACHE={{justfile_directory()}}/.cache/go-build GOMODCACHE={{justfile_directory()}}/.cache/go-mod GOTELEMETRY=off go test ./...

script-test:
    bash server/scripts/tests.sh

tf-validate:
    terraform -chdir=infra/terraform init -backend=false
    terraform -chdir=infra/terraform validate

tflint:
    tflint --chdir=infra/terraform

tf-plan:
    terraform -chdir=infra/terraform plan

flake-check:
    nix flake check

image-build IMAGE:
    nix build ".#{{IMAGE}}-image"

image-load IMAGE:
    docker load < "$(nix build --print-out-paths ".#{{IMAGE}}-image")"

dev-image-load IMAGE:
    docker load < "$(nix build --print-out-paths ".#packages.{{LOCAL_DOCKER_SYSTEM}}.{{IMAGE}}-image")"

image-push IMAGE TAG:
    skopeo copy "docker-archive:$(nix build --print-out-paths ".#{{IMAGE}}-image")" "docker://{{TAG}}"

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

ci:
    just test
    just script-test
    just flake-check
    terraform -chdir=infra/terraform fmt -check -recursive
    just tf-validate
    just tflint
