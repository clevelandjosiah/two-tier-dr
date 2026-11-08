# The dr-replication stack uses these to build the failover group
output "server_id" {
  value = azurerm_mssql_server.this.id
}

output "server_name" {
  value = azurerm_mssql_server.this.name
}

output "database_id" {
  value = try(azurerm_mssql_database.app[0].id, null)
}