variable "tfc_organization" {
  type = string
}

variable "tfc_workspace" {
  type = string
}

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

variable "azure_location" {
  type    = string
  default = "australiaeast"
}

variable "resource_name_prefix" {
  type    = string
  default = "minecraft"
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

variable "velocity_forwarding_secret" {
  type      = string
  sensitive = true
}

variable "minecraft_file_share_quota_gb" {
  type    = number
  default = 100
}

variable "gate_control_plane_role_name" {
  type    = string
  default = "Container Apps Contributor"
}

variable "minecraft_shutdown_grace" {
  type    = string
  default = "900"
}

variable "minecraft_scale_cooldown" {
  type    = number
  default = 900
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
