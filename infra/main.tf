module "azure_container_apps" {
  source = "./modules/azure-container-apps"

  location                        = var.azure_location
  resource_name_prefix            = var.resource_name_prefix
  gate_image                      = var.gate_image
  minecraft_image                 = var.minecraft_image
  picolimbo_image                 = var.picolimbo_image
  container_registry_server       = var.container_registry_server
  container_registry_username     = var.container_registry_username
  container_registry_password     = var.container_registry_password
  minecraft_file_share_quota_gb   = var.minecraft_file_share_quota_gb
  minecraft_world_container_name  = var.minecraft_world_container_name
  minecraft_sync_interval_seconds = var.minecraft_sync_interval_seconds
  velocity_forwarding_secret      = var.velocity_forwarding_secret
  minecraft_shutdown_grace        = var.minecraft_shutdown_grace
  minecraft_concurrent_sessions   = var.minecraft_concurrent_sessions
  gate_min_replicas               = var.gate_min_replicas
  gate_max_replicas               = var.gate_max_replicas
  minecraft_cpu                   = var.minecraft_cpu
  minecraft_memory                = var.minecraft_memory
  gate_cpu                        = var.gate_cpu
  gate_memory                     = var.gate_memory
  picolimbo_cpu                   = var.picolimbo_cpu
  picolimbo_memory                = var.picolimbo_memory
}

module "cloudflare" {
  source = "./modules/cloudflare"

  zone_id     = var.cloudflare_zone_id
  domain_name = var.minecraft_domain
  target      = module.azure_container_apps.gate_fqdn
}
