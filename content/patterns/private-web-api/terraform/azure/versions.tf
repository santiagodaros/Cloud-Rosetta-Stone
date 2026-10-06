terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8"
    }
  }
}

provider "azurerm" {
  features {}

  # Con shared_access_key_enabled = false el provider tiene que usar Entra ID
  # para las llamadas de data plane (gotcha: shared-key-needs-azuread-provider).
  storage_use_azuread = true

  # subscription_id se toma de ARM_SUBSCRIPTION_ID.
}
