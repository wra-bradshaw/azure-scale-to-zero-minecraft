module "azure_container_apps" {
  source = "./modules/azure-container-apps"

  location                      = var.azure_location
  resource_name_prefix          = var.resource_name_prefix
  gate_image                    = var.gate_image
  minecraft_image               = var.minecraft_image
  picolimbo_image               = var.picolimbo_image
  minecraft_file_share_quota_gb = var.minecraft_file_share_quota_gb
  velocity_forwarding_secret    = var.velocity_forwarding_secret
  azure_subscription_id         = var.azure_subscription_id
  gate_control_plane_role_name  = var.gate_control_plane_role_name
  minecraft_shutdown_grace      = var.minecraft_shutdown_grace
  minecraft_scale_cooldown      = var.minecraft_scale_cooldown
  minecraft_concurrent_sessions = var.minecraft_concurrent_sessions
  gate_min_replicas             = var.gate_min_replicas
  gate_max_replicas             = var.gate_max_replicas
  minecraft_cpu                 = var.minecraft_cpu
  minecraft_memory              = var.minecraft_memory
  gate_cpu                      = var.gate_cpu
  gate_memory                   = var.gate_memory
  picolimbo_cpu                 = var.picolimbo_cpu
  picolimbo_memory              = var.picolimbo_memory
}

module "cloudflare" {
  source = "./modules/cloudflare"

  zone_id     = var.cloudflare_zone_id
  domain_name = var.minecraft_domain
  target      = module.azure_container_apps.gate_fqdn
}
