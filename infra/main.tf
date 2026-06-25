locals {
  name_prefix       = lower(replace(var.resource_name_prefix, "_", "-"))
  minecraft_image   = "${var.image_repository}/minecraft:${var.image_tag}"
  gate_image        = "${var.image_repository}/gate-scale:${var.image_tag}"
  picolimbo_image   = "${var.image_repository}/picolimbo:${var.image_tag}"
  minecraft_port    = 25565
  waiting_port      = 25566
  files_volume_name = "minecraft-data"
  has_registry_auth = var.container_registry_username != null && var.container_registry_password != null
  storage_account   = substr(replace("${local.name_prefix}mcdata", "-", ""), 0, 24)
  environment_name  = "${local.name_prefix}-aca"
}

resource "terraform_data" "container_registry_auth_validation" {
  input = local.has_registry_auth

  lifecycle {
    precondition {
      condition     = local.has_registry_auth || (var.container_registry_username == null && var.container_registry_password == null)
      error_message = "container_registry_username and container_registry_password must be either both set or both unset."
    }
  }
}

data "azurerm_resource_group" "minecraft" {
  name = var.azure_resource_group_name
}

resource "azurerm_virtual_network" "minecraft" {
  name                = "${local.name_prefix}-vnet"
  location            = data.azurerm_resource_group.minecraft.location
  resource_group_name = data.azurerm_resource_group.minecraft.name
  address_space       = ["10.42.0.0/16"]
}

resource "azurerm_subnet" "container_apps" {
  name                 = "container-apps"
  resource_group_name  = data.azurerm_resource_group.minecraft.name
  virtual_network_name = azurerm_virtual_network.minecraft.name
  address_prefixes     = ["10.42.0.0/23"]

  delegation {
    name = "container-apps"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_log_analytics_workspace" "minecraft" {
  name                = "${local.name_prefix}-logs"
  location            = data.azurerm_resource_group.minecraft.location
  resource_group_name = data.azurerm_resource_group.minecraft.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "minecraft" {
  name                       = local.environment_name
  location                   = data.azurerm_resource_group.minecraft.location
  resource_group_name        = data.azurerm_resource_group.minecraft.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.minecraft.id
  infrastructure_subnet_id   = azurerm_subnet.container_apps.id
}

resource "azurerm_storage_account" "minecraft" {
  name                     = local.storage_account
  location                 = data.azurerm_resource_group.minecraft.location
  resource_group_name      = data.azurerm_resource_group.minecraft.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "minecraft" {
  name               = "minecraft"
  storage_account_id = azurerm_storage_account.minecraft.id
  quota              = var.minecraft_file_share_quota_gb
}

resource "azurerm_container_app_environment_storage" "minecraft" {
  name                         = local.files_volume_name
  container_app_environment_id = azurerm_container_app_environment.minecraft.id
  account_name                 = azurerm_storage_account.minecraft.name
  share_name                   = azurerm_storage_share.minecraft.name
  access_key                   = azurerm_storage_account.minecraft.primary_access_key
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app" "minecraft" {
  name                         = "minecraft"
  container_app_environment_id = azurerm_container_app_environment.minecraft.id
  resource_group_name          = data.azurerm_resource_group.minecraft.name
  revision_mode                = "Single"

  secret {
    name  = "velocity-forwarding-secret"
    value = var.velocity_forwarding_secret
  }

  dynamic "secret" {
    for_each = local.has_registry_auth ? [1] : []

    content {
      name  = "container-registry-password"
      value = var.container_registry_password
    }
  }

  dynamic "registry" {
    for_each = local.has_registry_auth ? [1] : []

    content {
      server               = var.container_registry_server
      username             = var.container_registry_username
      password_secret_name = "container-registry-password"
    }
  }

  ingress {
    external_enabled = false
    target_port      = local.minecraft_port
    transport        = "tcp"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 0
    max_replicas = 1

    tcp_scale_rule {
      name                = "minecraft-tcp"
      concurrent_requests = var.minecraft_concurrent_sessions
    }

    volume {
      name         = local.files_volume_name
      storage_name = azurerm_container_app_environment_storage.minecraft.name
      storage_type = "AzureFile"
    }

    container {
      name   = "minecraft"
      image  = local.minecraft_image
      cpu    = var.minecraft_cpu
      memory = var.minecraft_memory

      env {
        name  = "MC_EULA"
        value = "true"
      }

      env {
        name        = "VELOCITY_FORWARDING_SECRET"
        secret_name = "velocity-forwarding-secret"
      }

      env {
        name  = "MC_DATA_DIR"
        value = "/srv/minecraft"
      }

      env {
        name  = "SHUTDOWN_GRACE_SECONDS"
        value = var.minecraft_shutdown_grace
      }

      volume_mounts {
        name = local.files_volume_name
        path = "/srv/minecraft"
      }
    }
  }
}

resource "azurerm_container_app" "gate" {
  name                         = "gate"
  container_app_environment_id = azurerm_container_app_environment.minecraft.id
  resource_group_name          = data.azurerm_resource_group.minecraft.name
  revision_mode                = "Single"

  secret {
    name  = "velocity-forwarding-secret"
    value = var.velocity_forwarding_secret
  }

  dynamic "secret" {
    for_each = local.has_registry_auth ? [1] : []

    content {
      name  = "container-registry-password"
      value = var.container_registry_password
    }
  }

  dynamic "registry" {
    for_each = local.has_registry_auth ? [1] : []

    content {
      server               = var.container_registry_server
      username             = var.container_registry_username
      password_secret_name = "container-registry-password"
    }
  }

  ingress {
    external_enabled = true
    target_port      = local.minecraft_port
    exposed_port     = local.minecraft_port
    transport        = "tcp"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.gate_min_replicas
    max_replicas = var.gate_max_replicas

    container {
      name   = "gate"
      image  = local.gate_image
      cpu    = var.gate_cpu
      memory = var.gate_memory

      env {
        name  = "MC_HOST"
        value = azurerm_container_app.minecraft.name
      }

      env {
        name  = "MC_PORT"
        value = tostring(local.minecraft_port)
      }

      env {
        name  = "MC_SERVER_NAME"
        value = "minecraft"
      }

      env {
        name  = "WAITING_SERVER_NAME"
        value = "waiting"
      }

      env {
        name  = "WAITING_HOST"
        value = "127.0.0.1"
      }

      env {
        name  = "WAITING_PORT"
        value = tostring(local.waiting_port)
      }

      env {
        name  = "WAKE_TIMEOUT"
        value = "8m"
      }

      env {
        name  = "WAKE_POLL_INTERVAL"
        value = "5s"
      }

      env {
        name  = "TRANSFER_RETRY_INTERVAL"
        value = "2s"
      }

      env {
        name  = "TRANSFER_MAX_ATTEMPTS"
        value = "5"
      }

      env {
        name  = "WAKE_FAILURE_COOLDOWN"
        value = "1m"
      }

      env {
        name  = "GATE_ALLOWED_PLAYERS"
        value = "MrMoose65"
      }

      env {
        name        = "VELOCITY_FORWARDING_SECRET"
        secret_name = "velocity-forwarding-secret"
      }
    }

    container {
      name   = "waiting"
      image  = local.picolimbo_image
      cpu    = var.picolimbo_cpu
      memory = var.picolimbo_memory

      env {
        name  = "PICOLIMBO_BIND_PORT"
        value = tostring(local.waiting_port)
      }

      env {
        name        = "VELOCITY_FORWARDING_SECRET"
        secret_name = "velocity-forwarding-secret"
      }
    }
  }
}

resource "cloudflare_dns_record" "minecraft" {
  zone_id = var.cloudflare_zone_id
  name    = var.minecraft_domain
  content = azurerm_container_app.gate.ingress[0].fqdn
  type    = "CNAME"
  ttl     = 1
  proxied = false
}
