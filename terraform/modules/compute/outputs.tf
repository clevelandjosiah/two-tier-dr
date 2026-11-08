# Front Door uses this as the region's origin
output "lb_public_ip" {
  value = azurerm_public_ip.lb.ip_address
}

# Site Recovery adds failed-over VMs to this pool
output "backend_pool_id" {
  value = azurerm_lb_backend_address_pool.web.id
}

# Backup and Site Recovery protect these
output "vm_ids" {
  value = { for z, vm in azurerm_linux_virtual_machine.web : z => vm.id }
}