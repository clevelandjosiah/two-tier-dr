output "sql_dns_zone_id" {
  value = azurerm_private_dns_zone.sql.id
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}