terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate19323"
    container_name       = "tfstate"
    key                  = "two-tier-dr/dr-cus.tfstate"
    use_azuread_auth     = true # Entra ID login, no storage keys
  }
}