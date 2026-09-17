terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.65"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.15"
    }
  }

  # Remote state shared between local runs and CI. Bootstrapped once outside
  # this config (see tfstate-rg / tfstatedbriksd248f2 storage account).
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstatedbriksd248f2"
    container_name       = "tfstate"
    key                  = "terraform-azure.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# Account-level provider, used to create/assign the Unity Catalog metastore.
# Authenticates as an Azure AD service principal that must be added as an
# account admin in the Databricks account console (accounts.azuredatabricks.net).
provider "databricks" {
  alias = "accounts"

  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id

  azure_client_id     = var.databricks_client_id
  azure_client_secret = var.databricks_client_secret
  azure_tenant_id     = var.tenant_id
}
