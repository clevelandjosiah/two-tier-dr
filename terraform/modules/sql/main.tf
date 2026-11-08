# SQL server names must be unique across all of Azure
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_mssql_server" "this" {
  name                          = "sql-dr-${var.name_suffix}-${random_string.suffix.result}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false # reachable only through the private endpoint
  tags                          = var.tags

  # Entra ID login only: no SQL usernames or passwords exist
  azuread_administrator {
    login_username              = var.admin_login
    object_id                   = var.admin_object_id
    azuread_authentication_only = true
  }
}

resource "azurerm_mssql_database" "app" {
  count                = var.create_database ? 1 : 0
  name                 = "sqldb-app"
  server_id            = azurerm_mssql_server.this.id
  sku_name             = var.database_sku
  storage_account_type = "Geo" # SQL's own backups are geo-redundant
  tags                 = var.tags
}

# Gives SQL a private IP in the data subnet, and writes the DNS record for it
resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql-${var.name_suffix}"
    private_connection_resource_id = azurerm_mssql_server.this.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.dns_zone_id]
  }
}

# Lets this region's VNet read the private DNS zone
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "link-vnet-${var.name_suffix}"
  resource_group_name   = var.dns_zone_resource_group
  private_dns_zone_name = var.dns_zone_name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}