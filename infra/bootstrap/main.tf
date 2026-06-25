locals {
  github_repository_full_name = "${var.github_owner}/${var.github_repository}"
  github_deploy_branch        = "main"
  github_deploy_environment   = "production"
  github_oidc_subject         = "repo:${local.github_repository_full_name}:environment:${local.github_deploy_environment}"
  github_actions_app_name     = "${var.github_owner}-${var.github_repository}-github-actions"
  location                    = "australiaeast"
  state_container_name        = "tfstate"
  state_key                   = "mc-server-prod.tfstate"
  application_resource_group  = "${var.resource_name_prefix}-rg"

  state_tags = {
    managed_by = "terraform"
    purpose    = "terraform-state"
  }

  application_tags = {
    managed_by = "terraform"
    purpose    = "minecraft-server"
  }

  github_actions_variables = {
    AZURE_CLIENT_ID               = azuread_application.github_actions.client_id
    AZURE_TENANT_ID               = data.azurerm_client_config.current.tenant_id
    AZURE_SUBSCRIPTION_ID         = data.azurerm_client_config.current.subscription_id
    AZURE_LOCATION                = local.location
    AZURE_RESOURCE_GROUP_NAME     = azurerm_resource_group.minecraft.name
    RESOURCE_NAME_PREFIX          = var.resource_name_prefix
    MINECRAFT_DOMAIN              = var.minecraft_domain
    CLOUDFLARE_ZONE_ID            = var.cloudflare_zone_id
    TF_STATE_RESOURCE_GROUP_NAME  = azurerm_resource_group.state.name
    TF_STATE_STORAGE_ACCOUNT_NAME = azurerm_storage_account.state.name
    TF_STATE_CONTAINER_NAME       = azurerm_storage_container.state.name
    TF_STATE_KEY                  = local.state_key
  }
}

data "azuread_client_config" "current" {}
data "azurerm_client_config" "current" {}

resource "azuread_application" "github_actions" {
  display_name = local.github_actions_app_name
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "github_actions" {
  client_id                    = azuread_application.github_actions.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "github_actions_production" {
  application_id = azuread_application.github_actions.id
  display_name   = "${var.github_repository}-${local.github_deploy_environment}"
  description    = "GitHub Actions deploys ${local.github_repository_full_name} to ${local.github_deploy_environment}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = local.github_oidc_subject
}

resource "random_password" "velocity_forwarding_secret" {
  length  = 32
  special = false
}

data "cloudflare_zone" "minecraft" {
  zone_id = var.cloudflare_zone_id
}

data "cloudflare_account_api_token_permission_groups_list" "zone_read" {
  # Allows Terraform to read the target zone metadata before managing records.
  account_id = data.cloudflare_zone.minecraft.account.id
  name       = "Zone Read"
}

data "cloudflare_account_api_token_permission_groups_list" "dns_write" {
  # Allows Terraform to create and update DNS records in only the target zone.
  account_id = data.cloudflare_zone.minecraft.account.id
  name       = "DNS Write"
}

resource "cloudflare_account_token" "github_actions" {
  account_id = data.cloudflare_zone.minecraft.account.id
  name       = "${local.github_repository_full_name} GitHub Actions Terraform deploy"

  policies = [{
    effect = "allow"

    permission_groups = [
      {
        id = data.cloudflare_account_api_token_permission_groups_list.zone_read.result[0].id
      },
      {
        id = data.cloudflare_account_api_token_permission_groups_list.dns_write.result[0].id
      },
    ]

    resources = jsonencode({
      "com.cloudflare.api.account.zone.${var.cloudflare_zone_id}" = "*"
    })
  }]
}

resource "azurerm_resource_group" "state" {
  name     = var.state_resource_group_name
  location = local.location

  tags = local.state_tags
}

resource "azurerm_resource_group" "minecraft" {
  name     = local.application_resource_group
  location = local.location

  tags = local.application_tags
}

resource "azurerm_storage_account" "state" {
  name                            = var.state_storage_account_name
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  tags = local.state_tags
}

resource "azurerm_storage_container" "state" {
  name                  = local.state_container_name
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "github_actions_deploy" {
  scope                            = azurerm_resource_group.minecraft.id
  role_definition_name             = "Contributor"
  principal_id                     = azuread_service_principal.github_actions.object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "github_actions_state" {
  scope                            = azurerm_storage_container.state.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azuread_service_principal.github_actions.object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "github_repository_environment" "production" {
  repository  = var.github_repository
  environment = local.github_deploy_environment

  prevent_self_review = true
  can_admins_bypass   = true

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "production_main" {
  repository     = var.github_repository
  environment    = github_repository_environment.production.environment
  branch_pattern = local.github_deploy_branch
}

resource "github_actions_environment_variable" "deploy" {
  for_each = local.github_actions_variables

  repository    = var.github_repository
  environment   = github_repository_environment.production.environment
  variable_name = each.key
  value         = each.value
}

resource "github_actions_environment_secret" "velocity_forwarding_secret" {
  repository  = var.github_repository
  environment = github_repository_environment.production.environment
  secret_name = "VELOCITY_FORWARDING_SECRET"
  value       = random_password.velocity_forwarding_secret.result
}

resource "github_actions_environment_secret" "cloudflare_api_token" {
  repository  = var.github_repository
  environment = github_repository_environment.production.environment
  secret_name = "CLOUDFLARE_API_TOKEN"
  value       = cloudflare_account_token.github_actions.value
}
