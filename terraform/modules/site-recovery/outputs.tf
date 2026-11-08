output "vault_name" {
  value = azurerm_recovery_services_vault.asr.name
}

output "recovery_plan_name" {
  value = azurerm_site_recovery_replication_recovery_plan.web.name
}