terraform {
  required_version = ">= 1.8.0"

  cloud {
    organization = var.tfc_organization

    workspaces {
      name = var.tfc_workspace
    }
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
