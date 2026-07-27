terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Random suffix to keep the state storage account name globally unique
resource "random_integer" "suffix" {
  min = 10000
  max = 99999
}

# Storage account that holds all environment state files (the azurerm backend).
# Placed in the existing app resource group, which is the only scope this user
# has Contributor on.
resource "azurerm_storage_account" "state" {
  name                     = substr("${lower(replace(var.project, "-", ""))}tf${random_integer.suffix.result}", 0, 24)
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  # No anonymous access to the state account
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
  }

  # Protect the state account from accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project}-tfstate"
    Environment = "bootstrap"
    Project     = var.project
  }
}

# Container holding the per-environment state blobs
resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}
