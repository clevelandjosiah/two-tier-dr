resource "azurerm_resource_group" "this" {
  name     = "rg-dr-global"
  location = var.location
  tags     = var.tags
}

# One zone shared by both regions. Each SQL private endpoint adds its own record.
resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}