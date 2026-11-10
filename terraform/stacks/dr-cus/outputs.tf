# Read by the dr-replication and global stacks
output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "resource_group_id" {
  value = azurerm_resource_group.this.id
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

output "lb_public_ip" {
  value = module.compute.lb_public_ip
}

output "backend_pool_id" {
  value = module.compute.backend_pool_id
}

output "sql_server_id" {
  value = module.sql.server_id
}

output "lb_id" {
  value = module.compute.lb_id
}