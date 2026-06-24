# Terraform State Bootstrap

This stack creates the Azure Blob Storage backend used by the main `infra`
Terraform stack, creates the GitHub Actions OIDC application in Entra ID,
assigns the required Azure roles, writes the non-secret GitHub Actions
repository variables, generates the Velocity forwarding secret, creates a
zone-scoped Cloudflare API token, and writes generated secrets to GitHub.

Keep it separate from the Minecraft stack so the backend is not managed by the
state stored inside that same backend. This stack uses local Terraform state,
which is sensitive and ignored by the repository `.gitignore`.

## Usage

Create local bootstrap variables:

```sh
cp infra/bootstrap/bootstrap.auto.tfvars.example infra/bootstrap/local.auto.tfvars
$EDITOR infra/bootstrap/local.auto.tfvars
```

The storage account name must be globally unique, 3-24 characters, and contain
only lowercase letters and numbers.

Export credentials for the current shell:

```sh
export GITHUB_TOKEN="$(gh auth token)"
export CLOUDFLARE_API_KEY="<cloudflare-global-api-key-with-api-token-write-access>"
```

The Cloudflare CLI OAuth token is not used here. Use `CLOUDFLARE_API_KEY` for
bootstrap Cloudflare authentication.

Authenticate to Azure:

```sh
az login
az account set --subscription "<subscription-id>"
```

Run bootstrap:

```sh
terraform -chdir=infra/bootstrap init
terraform -chdir=infra/bootstrap apply
```

Create local backend config:

```sh
cp infra/backend.prod.tfbackend.example infra/backend.prod.tfbackend
$EDITOR infra/backend.prod.tfbackend
```

Initialize the main stack:

```sh
terraform -chdir=infra init -backend-config=backend.prod.tfbackend
```

The bootstrap stack sets these GitHub repository variables:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_LOCATION`
- `AZURE_RESOURCE_GROUP_NAME`
- `RESOURCE_NAME_PREFIX`
- `MINECRAFT_DOMAIN`
- `CLOUDFLARE_ZONE_ID`
- `TF_STATE_RESOURCE_GROUP_NAME`
- `TF_STATE_STORAGE_ACCOUNT_NAME`
- `TF_STATE_CONTAINER_NAME`
- `TF_STATE_KEY`

The bootstrap stack generates and sets these GitHub repository secrets:

- `CLOUDFLARE_API_TOKEN`
- `VELOCITY_FORWARDING_SECRET`

The generated Cloudflare token is scoped to the configured zone with:

- `Zone Read`
- `DNS Write`

Set these GitHub repository secrets manually if needed:

- Optional: `CONTAINER_REGISTRY_USERNAME`
- Optional: `CONTAINER_REGISTRY_PASSWORD`

For GitHub Actions, the workflow uses OIDC backend auth from the repository
variables written by bootstrap.

Inspect the generated backend and OIDC values with:

```sh
terraform -chdir=infra/bootstrap output backend_config
terraform -chdir=infra/bootstrap output github_actions_variables
```
