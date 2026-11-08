output "app_url" {
  value = module.front_door.url
}

output "sql_listener" {
  description = "The name the app connects to. It follows whichever server is primary."
  value       = "${azurerm_mssql_failover_group.this.name}.database.windows.net"
}

output "recovery_plan" {
  value = module.site_recovery.recovery_plan_name
}