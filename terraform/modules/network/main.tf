# Subnet ranges are carved from the VNet range, so one input sets all three
locals {
  subnets = {
    bastion = cidrsubnet(var.address_space, 10, 0) # x.x.0.0/26
    app     = cidrsubnet(var.address_space, 8, 2)  # x.x.2.0/24
    data    = cidrsubnet(var.address_space, 8, 3)  # x.x.3.0/24
  }
}

locals {
  sql_destinations = var.peer_address_space == null ? [local.subnets.data] : [local.subnets.data, cidrsubnet(var.peer_address_space, 8, 3)]
  sql_sources      = var.peer_address_space == null ? [local.subnets.app] : [local.subnets.app, cidrsubnet(var.peer_address_space, 8, 2)]
}

# ---------- VNet and subnets ----------

resource "azurerm_virtual_network" "this" {
  name                = "vnet-dr-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet" # Azure requires this exact name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.subnets.bastion]
}

resource "azurerm_subnet" "app" {
  name                            = "snet-app"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [local.subnets.app]
  default_outbound_access_enabled = false # outbound only through NAT
}

resource "azurerm_subnet" "data" {
  name                              = "snet-data"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [local.subnets.data]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = "Enabled" # without this, the NSG ignores the SQL endpoint
}

# ---------- NSGs ----------

resource "azurerm_network_security_group" "app" {
  name                = "nsg-app-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowFrontDoorHttp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureFrontDoor.Backend"
    destination_address_prefix = local.subnets.app
  }

  security_rule {
    name                       = "AllowLoadBalancerProbe"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = local.subnets.app
  }

  security_rule {
    name                       = "AllowSshFromBastion"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.subnets.bastion
    destination_address_prefix = local.subnets.app
  }

  security_rule {
    name                       = "DenyVnetInbound" # overrides Azure's allow-all-VNet default
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                         = "AllowSqlToData"
    priority                     = 100
    direction                    = "Outbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "1433"
    source_address_prefix        = local.subnets.app
    destination_address_prefixes = local.sql_destinations
  }

  security_rule {
    name                       = "DenyVnetOutbound" # stops lateral movement from a compromised web VM
    priority                   = 4000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_network_security_group" "data" {
  name                = "nsg-data-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowSqlFromApp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefixes    = local.sql_sources
    destination_address_prefix = local.subnets.data
  }

  security_rule {
    name                       = "DenyVnetInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

# Azure's required rule set for Bastion. Missing any rule fails the deployment.
resource "azurerm_network_security_group" "bastion" {
  name                = "nsg-bastion-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancerInbound"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowBastionHostCommunication"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowSshRdpOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAzureCloudOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }

  security_rule {
    name                       = "AllowBastionCommunication"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowHttpOutbound"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

locals {
  nsg_by_subnet = {
    bastion = { subnet_id = azurerm_subnet.bastion.id, nsg_id = azurerm_network_security_group.bastion.id }
    app     = { subnet_id = azurerm_subnet.app.id, nsg_id = azurerm_network_security_group.app.id }
    data    = { subnet_id = azurerm_subnet.data.id, nsg_id = azurerm_network_security_group.data.id }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = local.nsg_by_subnet
  subnet_id                 = each.value.subnet_id
  network_security_group_id = each.value.nsg_id
}

# ---------- NAT gateway: outbound internet for the app subnet ----------

resource "azurerm_public_ip" "nat" {
  name                = "pip-nat-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "this" {
  name                    = "nat-dr-${var.name_suffix}"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "app" {
  subnet_id      = azurerm_subnet.app.id
  nat_gateway_id = azurerm_nat_gateway.this.id
}

# ---------- Bastion: admin access with no public IPs on VMs ----------

resource "azurerm_public_ip" "bastion" {
  count               = var.deploy_bastion ? 1 : 0
  name                = "pip-bas-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "this" {
  count               = var.deploy_bastion ? 1 : 0
  name                = "bas-dr-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tunneling_enabled   = true
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  # The NSG must be attached before Bastion deploys
  depends_on = [azurerm_subnet_network_security_group_association.this]
}

