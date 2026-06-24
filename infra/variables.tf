variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_zone_id" {
  type = string
}

variable "minecraft_domain" {
  type = string
}

variable "azure_subscription_id" {
  type = string
}

variable "azure_tenant_id" {
  type = string
}

variable "azure_location" {
  type    = string
  default = "australiaeast"
}

variable "resource_name_prefix" {
  type = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,16}[a-z0-9]$", var.resource_name_prefix))
    error_message = "resource_name_prefix must be 3-18 lowercase letters, numbers, or hyphens, start with a letter, and end with a letter or number."
  }
}

variable "minecraft_image" {
  type = string
}

variable "gate_image" {
  type = string
}

variable "picolimbo_image" {
  type = string
}

variable "container_registry_server" {
  type    = string
  default = "ghcr.io"
}

variable "container_registry_username" {
  type     = string
  default  = null
  nullable = true
}

variable "container_registry_password" {
  type      = string
  default   = null
  nullable  = true
  sensitive = true
}

variable "velocity_forwarding_secret" {
  type      = string
  sensitive = true
}

variable "minecraft_file_share_quota_gb" {
  type    = number
  default = 100
}

variable "minecraft_shutdown_grace" {
  type    = string
  default = "900"
}

variable "minecraft_concurrent_sessions" {
  type    = number
  default = 1
}

variable "gate_min_replicas" {
  type    = number
  default = 1
}

variable "gate_max_replicas" {
  type    = number
  default = 1
}

variable "minecraft_cpu" {
  type    = number
  default = 2
}

variable "minecraft_memory" {
  type    = string
  default = "4Gi"
}

variable "gate_cpu" {
  type    = number
  default = 0.25
}

variable "gate_memory" {
  type    = string
  default = "0.5Gi"
}

variable "picolimbo_cpu" {
  type    = number
  default = 0.25
}

variable "picolimbo_memory" {
  type    = string
  default = "0.5Gi"
}
