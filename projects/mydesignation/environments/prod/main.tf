terraform {
  required_version = ">= 1.5.0"

  backend "azurerm" {
    resource_group_name  = "rg-myd-mobileapp-dev"
    storage_account_name = "REPLACE_WITH_BOOTSTRAP_OUTPUT"
    container_name       = "tfstate"
    key                  = "mydesignation/prod/terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# ---------------------------------------------------------------------------
# prod is scaffolded but empty. Add module blocks here, mirroring
# environments/staging/main.tf, then `terraform apply` to CREATE the
# resources (no import blocks — these are net-new).
# ---------------------------------------------------------------------------
