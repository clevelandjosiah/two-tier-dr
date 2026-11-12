# ---------- Read both regions' outputs ----------

data "terraform_remote_state" "primary" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = var.state_storage_account
    container_name       = "tfstate"
    key                  = "two-tier-dr/primary-wus3.tfstate"
    use_azuread_auth     = true
  }
}

data "terraform_remote_state" "dr" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = var.state_storage_account
    container_name       = "tfstate"
    key                  = "two-tier-dr/dr-cus.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  primary = data.terraform_remote_state.primary.outputs
  dr      = data.terraform_remote_state.dr.outputs
}

# ---------- VNet peering, needed in both directions ----------

resource "azurerm_virtual_network_peering" "primary_to_dr" {
  name                         = "peer-wus3-to-cus"
  resource_group_name          = local.primary.resource_group_name
  virtual_network_name         = local.primary.vnet_name
  remote_virtual_network_id    = local.dr.vnet_id
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "dr_to_primary" {
  name                         = "peer-cus-to-wus3"
  resource_group_name          = local.dr.resource_group_name
  virtual_network_name         = local.dr.vnet_name
  remote_virtual_network_id    = local.primary.vnet_id
  allow_virtual_network_access = true
}

# ---------- SQL failover group ----------

resource "random_string" "fog" {
  length  = 4
  upper   = false
  special = false
}

# Creates the secondary database in Central US and gives the app one name to use
resource "azurerm_mssql_failover_group" "this" {
  name      = "fog-two-tier-dr-${random_string.fog.result}"
  server_id = local.primary.sql_server_id
  databases = [local.primary.sql_database_id]
  tags      = var.tags

  partner_server {
    id = local.dr.sql_server_id
  }

  # You decide when to fail over, as part of the runbook
  read_write_endpoint_failover_policy {
    mode = "Manual"
  }
}

# ---------- Site Recovery ----------

module "site_recovery" {
  source                     = "../../modules/site-recovery"
  location                   = var.dr_location
  resource_group_name        = local.dr.resource_group_name
  source_location            = var.primary_location
  source_resource_group_name = local.primary.resource_group_name
  source_vnet_id             = local.primary.vnet_id
  target_vnet_id             = local.dr.vnet_id
  target_resource_group_id   = local.dr.resource_group_id
  target_backend_pool_id     = local.dr.backend_pool_id
  vms                        = local.primary.vms
  tags                       = var.tags
}

# ---------- Front Door ----------

data "azurerm_resource_group" "global" {
  name = "rg-dr-global"
}

module "front_door" {
  source              = "../../modules/front-door"
  resource_group_name = data.azurerm_resource_group.global.name
  primary_origin_ip   = local.primary.lb_public_ip
  secondary_origin_ip = local.dr.lb_public_ip
  tags                = var.tags
}

# ---------- Monitoring ----------

data "azurerm_log_analytics_workspace" "lab" {
  name                = "law-dr-lab"
  resource_group_name = "rg-dr-global"
}

module "monitoring" {
  source               = "../../modules/monitoring"
  resource_group_name  = data.azurerm_resource_group.global.name
  location             = data.azurerm_resource_group.global.location
  workspace_id         = data.azurerm_log_analytics_workspace.lab.id
  alert_email          = var.alert_email
  frontdoor_profile_id = module.front_door.profile_id
  primary_lb_id        = local.primary.lb_id
  tags                 = var.tags

  diagnostic_targets = {
    frontdoor    = module.front_door.profile_id
    lb_primary   = local.primary.lb_id
    lb_dr        = local.dr.lb_id
    sql_primary  = local.primary.sql_database_id
    backup_vault = local.primary.backup_vault_id
    asr_vault    = module.site_recovery.vault_id
  }
}