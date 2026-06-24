output "resource_group_name" {
  value = azurerm_resource_group.state.name
}

output "storage_account_name" {
  value = azurerm_storage_account.state.name
}

output "container_name" {
  value = azurerm_storage_container.state.name
}

output "backend_config" {
  value = {
    resource_group_name  = azurerm_resource_group.state.name
    storage_account_name = azurerm_storage_account.state.name
    container_name       = azurerm_storage_container.state.name
    key                  = local.state_key
    use_oidc             = true
    use_azuread_auth     = true
    client_id            = azuread_application.github_actions.client_id
    tenant_id            = data.azurerm_client_config.current.tenant_id
    subscription_id      = data.azurerm_client_config.current.subscription_id
  }
}

output "github_actions_client_id" {
  value = azuread_application.github_actions.client_id
}

output "github_actions_service_principal_object_id" {
  value = azuread_service_principal.github_actions.object_id
}

output "github_oidc_subject" {
  value = azuread_application_federated_identity_credential.github_actions_main.subject
}

output "github_actions_variables" {
  value = local.github_actions_variables
}

output "github_actions_generated_secrets" {
  value = [
    github_actions_secret.cloudflare_api_token.secret_name,
    github_actions_secret.velocity_forwarding_secret.secret_name,
  ]
}
