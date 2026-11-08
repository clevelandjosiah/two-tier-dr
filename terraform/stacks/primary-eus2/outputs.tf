# Read later by the dr-replication stack for peering and failover settings
output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "vnet_id" {
  value = module.network.vnet_id
}

output "vnet_name" {
  value = module.network.vnet_name
}

output "subnet_ids" {
  value = module.network.subnet_ids
}

output "subnet_prefixes" {
  value = module.network.subnet_prefixes
}

output "sql_server_id" {
  value = module.sql.server_id
}

output "sql_database_id" {
  value = module.sql.database_id
}

output "vms" {
  value = module.compute.vms
}