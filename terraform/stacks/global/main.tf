resource "azurerm_resource_group" "this" {
  name     = "rg-dr-global"
  location = var.location
  tags     = var.tags
}

# One zone shared by both regions. Each SQL private endpoint adds its own record.
resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

# ---------- Monitoring ----------

resource "azurerm_log_analytics_workspace" "this" {
  name                = "law-dr-lab"
  location            = azurerm_resource_group.this.location # Central US, so it survives a primary outage
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ---------- Governance ----------

data "azurerm_management_group" "lab" {
  name = "mg-dr-lab"
}

# Blocks any resource outside the two lab regions
resource "azurerm_management_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed locations: East US 2 and Central US"
  management_group_id  = data.azurerm_management_group.lab.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"

  parameters = jsonencode({
    listOfAllowedLocations = { value = ["eastus2", "centralus"] }
  })
}

# Reports untagged resources without blocking them
resource "azurerm_management_group_policy_assignment" "require_project_tag" {
  name                 = "require-project-tag"
  display_name         = "Require a project tag (audit only)"
  management_group_id  = data.azurerm_management_group.lab.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
  enforce              = false

  parameters = jsonencode({
    tagName = { value = "project" }
  })
}