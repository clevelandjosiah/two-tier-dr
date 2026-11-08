terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.9"
    }
  }
}

# Subscription and login come from environment variables:
# ARM_SUBSCRIPTION_ID locally, plus the OIDC variables in the pipeline
provider "azurerm" {
  features {}
  storage_use_azuread = true
}