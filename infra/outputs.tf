output "gate_fqdn" {
  value = module.azure_container_apps.gate_fqdn
}

output "gate_port" {
  value = module.azure_container_apps.gate_port
}

output "minecraft_file_share_name" {
  value = module.azure_container_apps.minecraft_file_share_name
}

output "gate_container_app_name" {
  value = module.azure_container_apps.gate_container_app_name
}

output "minecraft_container_app_name" {
  value = module.azure_container_apps.minecraft_container_app_name
}

output "container_app_environment_name" {
  value = module.azure_container_apps.container_app_environment_name
}
