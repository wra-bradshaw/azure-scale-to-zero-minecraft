provider "azuread" {}

provider "azurerm" {
  features {}
}

provider "cloudflare" {
  api_token = var.cloudflare_bootstrap_api_token
}

provider "github" {
  owner = var.github_owner
}
