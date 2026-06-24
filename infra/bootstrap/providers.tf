provider "azuread" {}

provider "azurerm" {
  features {}
}

provider "cloudflare" {}

provider "github" {
  owner = var.github_owner
}
