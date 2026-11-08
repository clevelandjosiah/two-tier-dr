output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  value = {
    bastion = azurerm_subnet.bastion.id
    app     = azurerm_subnet.app.id
    data    = azurerm_subnet.data.id
  }
}

output "subnet_prefixes" {
  value = local.subnets
}

output "nat_public_ip" {
  value = azurerm_public_ip.nat.ip_address
}