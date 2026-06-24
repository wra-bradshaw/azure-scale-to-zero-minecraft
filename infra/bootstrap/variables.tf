variable "github_owner" {
  type = string
}

variable "github_repository" {
  type = string
}

variable "resource_name_prefix" {
  type = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,16}[a-z0-9]$", var.resource_name_prefix))
    error_message = "resource_name_prefix must be 3-18 lowercase letters, numbers, or hyphens, start with a letter, and end with a letter or number."
  }
}

variable "minecraft_domain" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "state_resource_group_name" {
  type = string
}

variable "state_storage_account_name" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.state_storage_account_name))
    error_message = "state_storage_account_name must be 3-24 lowercase letters or numbers."
  }
}
