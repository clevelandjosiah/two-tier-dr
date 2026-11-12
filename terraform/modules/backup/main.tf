resource "azurerm_recovery_services_vault" "this" {
  name                         = "rsv-backup-${var.name_suffix}"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  sku                          = "Standard"
  storage_mode_type            = "GeoRedundant" # copies backups to Central US
  cross_region_restore_enabled = true           # lets you restore there if West US 3 is down
  soft_delete_enabled          = var.soft_delete_enabled
  tags                         = var.tags
}

resource "azurerm_backup_policy_vm" "daily" {
  name                           = "bkpol-daily-${var.name_suffix}"
  resource_group_name            = var.resource_group_name
  recovery_vault_name            = azurerm_recovery_services_vault.this.name
  timezone                       = "Eastern Standard Time"
  instant_restore_retention_days = 2 # snapshots kept locally for fast restores

  backup {
    frequency = "Daily"
    time      = var.backup_time
  }

  retention_daily {
    count = var.retention_days
  }
}

resource "azurerm_backup_protected_vm" "web" {
  for_each            = var.vm_ids
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.this.name
  source_vm_id        = each.value
  backup_policy_id    = azurerm_backup_policy_vm.daily.id
}