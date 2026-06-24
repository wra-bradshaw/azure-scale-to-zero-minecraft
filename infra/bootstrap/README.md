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

Authenticate to Azure and set a GitHub token that can manage Actions variables
for the repository:

```sh
export GITHUB_TOKEN="<github-token>"
export TF_VAR_cloudflare_bootstrap_api_token="<cloudflare-token-with-api-token-write-access>"
```

Then run:

```sh
terraform -chdir=infra/bootstrap init
terraform -chdir=infra/bootstrap apply \
  -var github_owner="<github-owner>" \
  -var github_repository="<github-repository-name>" \
  -var resource_name_prefix="<minecraft-resource-prefix>" \
  -var minecraft_domain="<minecraft-domain>" \
  -var cloudflare_zone_id="<cloudflare-zone-id>" \
  -var cloudflare_bootstrap_api_token="${TF_VAR_cloudflare_bootstrap_api_token}" \
  -var state_resource_group_name="<state-resource-group>" \
  -var state_storage_account_name="<globally-unique-storage-account-name>"
```

The storage account name must be globally unique, 3-24 characters, and contain
only lowercase letters and numbers.

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

After this stack creates the empty backend, initialize the main stack against
that backend:

```sh
terraform -chdir=infra init \
  -backend-config="resource_group_name=<state-resource-group>" \
  -backend-config="storage_account_name=<globally-unique-storage-account-name>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=mc-server-prod.tfstate" \
  -backend-config="use_oidc=true" \
  -backend-config="use_azuread_auth=true" \
  -backend-config="client_id=<github-actions-client-id>" \
  -backend-config="tenant_id=<azure-tenant-id>"
```

For local initialization with an Azure CLI session, use `use_cli=true` instead
of `use_oidc=true` and omit `client_id`.

Inspect the generated backend and OIDC values with:

```sh
terraform -chdir=infra/bootstrap output backend_config
terraform -chdir=infra/bootstrap output github_actions_variables
```
