output "gate_fqdn" {
  value = azurerm_container_app.gate.ingress[0].fqdn
}

output "gate_port" {
  value = local.minecraft_port
}

output "minecraft_file_share_name" {
  value = azurerm_storage_share.minecraft.name
}

output "minecraft_world_container_name" {
  value = azurerm_storage_container.minecraft_world.name
}

output "gate_container_app_name" {
  value = azurerm_container_app.gate.name
}

output "minecraft_container_app_name" {
  value = azurerm_container_app.minecraft.name
}

output "container_app_environment_name" {
  value = azurerm_container_app_environment.minecraft.name
}
