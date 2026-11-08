locals {
  name_suffix = "eus2"
  tags        = merge(var.tags, { region_role = "primary" })
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