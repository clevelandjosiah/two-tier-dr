locals {
  name_suffix = "cus"
  tags        = merge(var.tags, { region_role = "dr" })
}

resource "azurerm_resource_group" "this" {
  name     = "rg-dr-${local.name_suffix}"
  location = var.location
  tags     = local.tags
}

module "network" {
  source              = "../../modules/network"
  name_suffix         = local.name_suffix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.address_space
  deploy_bastion      = var.deploy_bastion
  tags                = local.tags
}

# Load balancer only. Site Recovery creates the VMs during a failover.
module "compute" {
  source              = "../../modules/compute"
  name_suffix         = local.name_suffix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.network.subnet_ids.app
  zones               = []
  ssh_public_key      = file("${path.module}/../../keys/web.pub")
  tags                = local.tags
}

data "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = "rg-dr-global"
}

# Server only. The failover group creates the secondary database.
module "sql" {
  source                  = "../../modules/sql"
  name_suffix             = local.name_suffix
  location                = azurerm_resource_group.this.location
  resource_group_name     = azurerm_resource_group.this.name
  subnet_id               = module.network.subnet_ids.data
  vnet_id                 = module.network.vnet_id
  dns_zone_id             = data.azurerm_private_dns_zone.sql.id
  dns_zone_name           = data.azurerm_private_dns_zone.sql.name
  dns_zone_resource_group = data.azurerm_private_dns_zone.sql.resource_group_name
  admin_login             = var.sql_admin_login
  admin_object_id         = var.sql_admin_object_id
  create_database         = false
  tags                    = local.tags
}