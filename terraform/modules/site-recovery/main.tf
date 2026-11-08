# ---------- Vault: settings and recovery points, in the DR region ----------

resource "azurerm_recovery_services_vault" "asr" {
  name                = "rsv-asr-cus"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  soft_delete_enabled = false # lab teardown; true in production
  tags                = var.tags
}

# ---------- Cache account: the VM agents send writes here first ----------

resource "random_string" "cache" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "cache" {
  name                            = "stasrcache${random_string.cache.result}"
  location                        = var.source_location
  resource_group_name             = var.source_resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS" # buffers data for minutes, no geo-copy needed
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = var.tags
}

# ---------- Fabrics and containers: ASR's model of each region ----------

resource "azurerm_site_recovery_fabric" "source" {
  name                = "fabric-eus2"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.asr.name
  location            = var.source_location
}

resource "azurerm_site_recovery_fabric" "target" {
  name                = "fabric-cus"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.asr.name
  location            = var.location
}

resource "azurerm_site_recovery_protection_container" "source" {
  name                 = "container-eus2"
  resource_group_name  = var.resource_group_name
  recovery_vault_name  = azurerm_recovery_services_vault.asr.name
  recovery_fabric_name = azurerm_site_recovery_fabric.source.name
}

resource "azurerm_site_recovery_protection_container" "target" {
  name                 = "container-cus"
  resource_group_name  = var.resource_group_name
  recovery_vault_name  = azurerm_recovery_services_vault.asr.name
  recovery_fabric_name = azurerm_site_recovery_fabric.target.name
}

# ---------- Policy and mappings: how and where to replicate ----------

resource "azurerm_site_recovery_replication_policy" "this" {
  name                                                 = "policy-24h"
  resource_group_name                                  = var.resource_group_name
  recovery_vault_name                                  = azurerm_recovery_services_vault.asr.name
  recovery_point_retention_in_minutes                  = 24 * 60 # keep 24 hours of recovery points
  application_consistent_snapshot_frequency_in_minutes = 4 * 60  # app-consistent point every 4 hours
}

resource "azurerm_site_recovery_protection_container_mapping" "this" {
  name                                      = "map-eus2-to-cus"
  resource_group_name                       = var.resource_group_name
  recovery_vault_name                       = azurerm_recovery_services_vault.asr.name
  recovery_fabric_name                      = azurerm_site_recovery_fabric.source.name
  recovery_source_protection_container_name = azurerm_site_recovery_protection_container.source.name
  recovery_target_protection_container_id   = azurerm_site_recovery_protection_container.target.id
  recovery_replication_policy_id            = azurerm_site_recovery_replication_policy.this.id
}

resource "azurerm_site_recovery_network_mapping" "this" {
  name                        = "netmap-eus2-to-cus"
  resource_group_name         = var.resource_group_name
  recovery_vault_name         = azurerm_recovery_services_vault.asr.name
  source_recovery_fabric_name = azurerm_site_recovery_fabric.source.name
  target_recovery_fabric_name = azurerm_site_recovery_fabric.target.name
  source_network_id           = var.source_vnet_id
  target_network_id           = var.target_vnet_id
}

# ---------- Replicate each web VM ----------

resource "azurerm_site_recovery_replicated_vm" "web" {
  for_each                                  = var.vms
  name                                      = "repl-web-zone${each.key}"
  resource_group_name                       = var.resource_group_name
  recovery_vault_name                       = azurerm_recovery_services_vault.asr.name
  source_recovery_fabric_name               = azurerm_site_recovery_fabric.source.name
  source_vm_id                              = each.value.vm_id
  recovery_replication_policy_id            = azurerm_site_recovery_replication_policy.this.id
  source_recovery_protection_container_name = azurerm_site_recovery_protection_container.source.name
  target_resource_group_id                  = var.target_resource_group_id
  target_recovery_fabric_id                 = azurerm_site_recovery_fabric.target.id
  target_recovery_protection_container_id   = azurerm_site_recovery_protection_container.target.id
  target_network_id                         = var.target_vnet_id
  target_zone                               = each.key # zone 1 stays zone 1 in DR

  managed_disk {
    disk_id                    = each.value.os_disk_id
    staging_storage_account_id = azurerm_storage_account.cache.id
    target_resource_group_id   = var.target_resource_group_id
    target_disk_type           = "StandardSSD_LRS"
    target_replica_disk_type   = "StandardSSD_LRS"
  }

  network_interface {
    source_network_interface_id                     = each.value.nic_id
    target_subnet_name                              = var.target_subnet_name
    recovery_load_balancer_backend_address_pool_ids = [var.target_backend_pool_id]
  }

  depends_on = [
    azurerm_site_recovery_protection_container_mapping.this,
    azurerm_site_recovery_network_mapping.this,
  ]
}

# ---------- Recovery plan: fail over all web VMs in one action ----------

resource "azurerm_site_recovery_replication_recovery_plan" "web" {
  name                      = "rp-web-eus2-to-cus"
  recovery_vault_id         = azurerm_recovery_services_vault.asr.id
  source_recovery_fabric_id = azurerm_site_recovery_fabric.source.id
  target_recovery_fabric_id = azurerm_site_recovery_fabric.target.id

  shutdown_recovery_group {}
  failover_recovery_group {}

  boot_recovery_group {
    replicated_protected_items = [for r in azurerm_site_recovery_replicated_vm.web : r.id]
  }
}