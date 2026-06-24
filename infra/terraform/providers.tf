provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}
