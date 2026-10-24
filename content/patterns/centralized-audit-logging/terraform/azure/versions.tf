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

  # subscription_id se toma de ARM_SUBSCRIPTION_ID: la suscripción central de logging.
}
