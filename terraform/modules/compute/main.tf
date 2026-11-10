# Installs Nginx and a page showing which VM answered, so you can see
# load balancing and failover happen
locals {
  cloud_init = <<-EOT
    #cloud-config
    package_update: true
    packages:
      - nginx
    runcmd:
      - echo "<h1>two-tier-dr</h1><p>Served by $(hostname) in ${var.location}</p>" > /var/www/html/index.html
      - systemctl enable --now nginx
  EOT
}

# ---------- Load balancer ----------

resource "azurerm_public_ip" "lb" {
  name                = "pip-lb-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"] # zone-redundant frontend
  tags                = var.tags
}

resource "azurerm_lb" "web" {
  name                = "lb-dr-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "web" {
  name            = "web"
  loadbalancer_id = azurerm_lb.web.id
}

resource "azurerm_lb_probe" "http" {
  name            = "http"
  loadbalancer_id = azurerm_lb.web.id
  protocol        = "Http"
  port            = 80
  request_path    = "/"
}

resource "azurerm_lb_rule" "http" {
  name                           = "http"
  loadbalancer_id                = azurerm_lb.web.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.http.id
  disable_outbound_snat          = true # outbound goes through the NAT gateway instead
}

# ---------- Web VMs, one per zone ----------

resource "azurerm_network_interface" "web" {
  for_each            = toset(var.zones)
  name                = "nic-web-${var.name_suffix}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic" # no public IP
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "web" {
  for_each                = toset(var.zones)
  network_interface_id    = azurerm_network_interface.web[each.key].id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web.id
}

resource "azurerm_linux_virtual_machine" "web" {
  for_each                        = toset(var.zones)
  name                            = "vm-web-${var.name_suffix}-${each.key}"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  zone                            = each.key
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.web[each.key].id]
  custom_data                     = base64encode(local.cloud_init)
  tags                            = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  # Required by the Entra login extension
  identity {
    type = "SystemAssigned"
  }

  os_disk {
    name                 = "osdisk-web-${var.name_suffix}-${each.key}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {} # Azure-managed storage, viewable in the portal
}

# Lets users sign in with their Entra ID account instead of the SSH key
resource "azurerm_virtual_machine_extension" "aad_login" {
  for_each                   = toset(var.zones)
  name                       = "AADSSHLoginForLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.web[each.key].id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADSSHLoginForLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  tags                       = var.tags
}

# Site Recovery needs each VM's OS disk ID
data "azurerm_managed_disk" "os" {
  for_each            = toset(var.zones)
  name                = "osdisk-web-${var.name_suffix}-${each.key}"
  resource_group_name = var.resource_group_name
  depends_on          = [azurerm_linux_virtual_machine.web]
}