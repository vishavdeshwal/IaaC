terraform {
  required_version = ">= 1.5.0"

  # Backend storage account name comes from the bootstrap output.
  # Run projects/mydesignation/bootstrap first, then replace REPLACE_WITH_BOOTSTRAP_OUTPUT.
  backend "azurerm" {
    resource_group_name  = "rg-myd-mobileapp-dev"
    storage_account_name = "mydesignationtf17144"
    container_name       = "tfstate"
    key                  = "mydesignation/staging/terraform.tfstate"
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

// =============================================================
// Resource Group
// =============================================================

module "resource_group" {
  source        = "../../../../modules/azure/resource_group"
  name_override = "rg-myd-mobileapp-dev"
  location      = var.location
  environment   = var.environment
  project       = var.project
}

// =============================================================
// Network
// =============================================================

# App VNet (hosts the staging-application VM)
module "vnet_app" {
  source              = "../../../../modules/azure/virtual_network"
  name_override       = "staging-mydestination"
  location            = var.location
  resource_group_name = module.resource_group.name
  address_space       = ["10.0.0.0/16"]
  subnets             = var.vnet_app_subnets
  environment = var.environment
  project     = var.project
}

# Standalone production VNet (not currently wired to the app)
module "vnet_production" {
  source              = "../../../../modules/azure/virtual_network"
  name_override       = "production-vnet"
  location            = var.location
  resource_group_name = module.resource_group.name
  address_space       = ["10.1.0.0/16"]
  subnets             = var.vnet_production_subnets
  environment = var.environment
  project     = var.project
}

module "nsg_app" {
  source              = "../../../../modules/azure/network_security_group"
  name_override       = "staging-application-nsg"
  location            = var.location
  resource_group_name = module.resource_group.name
  security_rules = [
    {
      name                       = "SSH"
      priority                   = 300
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
    {
      name                       = "allow_443"
      priority                   = 330
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
  ]
  environment = var.environment
  project     = var.project
}

module "nsg_testing1" {
  source              = "../../../../modules/azure/network_security_group"
  name_override       = "testing1-nsg"
  location            = var.location
  resource_group_name = module.resource_group.name
  security_rules = [
    {
      name                       = "SSH"
      priority                   = 300
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
  ]
  environment = var.environment
  project     = var.project
}

module "nsg_testing1_715" {
  source              = "../../../../modules/azure/network_security_group"
  name_override       = "testing1nsg715"
  location            = var.location
  resource_group_name = module.resource_group.name
  security_rules      = []
  environment         = var.environment
  project             = var.project
}

module "pip_app" {
  source              = "../../../../modules/azure/public_ip"
  name_override       = "staging-application-ip"
  location            = var.location
  resource_group_name = module.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
  environment         = var.environment
  project             = var.project
}

module "pip_mydestination" {
  source              = "../../../../modules/azure/public_ip"
  name_override       = "staging-mydestination"
  location            = var.location
  resource_group_name = module.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
  environment         = var.environment
  project             = var.project
}

module "nic_app" {
  source                        = "../../../../modules/azure/network_interface"
  name_override                 = "staging-application485"
  location                      = var.location
  resource_group_name           = module.resource_group.name
  ip_configuration_name         = "ipconfig1"
  subnet_id                     = module.vnet_app.subnet_ids["default"]
  private_ip_address_allocation = "Dynamic"
  public_ip_address_id          = module.pip_app.id
  network_security_group_id     = module.nsg_app.id
  environment                   = var.environment
  project                       = var.project
}

// =============================================================
// Compute
// =============================================================

module "ssh_app" {
  source              = "../../../../modules/azure/ssh_public_key"
  name_override       = "staging-application_key"
  location            = var.location
  resource_group_name = module.resource_group.name
  public_key          = var.staging_application_ssh_public_key
  environment         = var.environment
  project             = var.project
}

module "ssh_testing1" {
  source              = "../../../../modules/azure/ssh_public_key"
  name_override       = "testing1_key"
  location            = var.location
  resource_group_name = module.resource_group.name
  public_key          = var.testing1_ssh_public_key
  environment         = var.environment
  project             = var.project
}

module "vm_app" {
  source                       = "../../../../modules/azure/linux_virtual_machine"
  name_override                = "staging-application"
  location                     = var.location
  resource_group_name          = module.resource_group.name
  size                         = "Standard_B2ms"
  admin_username               = "azureuser"
  admin_ssh_public_key         = var.staging_application_ssh_public_key
  network_interface_ids        = [module.nic_app.id]
  os_disk_caching              = "ReadWrite"
  os_disk_storage_account_type = "Premium_LRS"
  image_publisher              = "canonical"
  image_offer                  = "ubuntu-24_04-lts"
  image_sku                    = "server"
  image_version                = "latest"
  identity_type                = "SystemAssigned"
  secure_boot_enabled          = true # Trusted Launch VM
  vtpm_enabled                 = true # Trusted Launch VM
  environment                  = var.environment
  project                      = var.project
}

// =============================================================
// Storage
// =============================================================

module "storage" {
  source                          = "../../../../modules/azure/storage_account"
  name_override                   = "mydesignation"
  location                        = var.location
  resource_group_name             = module.resource_group.name
  account_tier                    = "Standard"
  account_replication_type        = "RAGRS"
  account_kind                    = "StorageV2"
  access_tier                     = "Hot"
  allow_nested_items_to_be_public = true # container 'staging-mydesignation-bucket' is public 'blob'
  containers = {
    "staging-mydesignation-bucket" = { access_type = "blob" }
  }
  queues      = ["staging-mydesignation-queue"] # legacy storage queue (superseded by Service Bus)
  environment = var.environment
  project     = var.project
}

// =============================================================
// Messaging (Service Bus)
// =============================================================

module "servicebus_namespace" {
  source              = "../../../../modules/azure/servicebus_namespace"
  name_override       = "staging-mydesignation-bus"
  location            = var.location
  resource_group_name = module.resource_group.name
  sku                 = "Basic"
  authorization_rules = {
    "webhook-app" = { listen = true, send = true, manage = false }
  }
  environment = var.environment
  project     = var.project
}

module "servicebus_queue" {
  source        = "../../../../modules/azure/servicebus_queue"
  name_override = "staging-mydesignation-queue"
  namespace_id  = module.servicebus_namespace.id

  max_delivery_count                   = 10
  dead_lettering_on_message_expiration = true
  lock_duration                        = "PT1M"
  max_size_in_megabytes                = 1024
  default_message_ttl                  = "P14D"

  authorization_rules = {
    "send-only"   = { listen = false, send = true, manage = false }
    "listen-only" = { listen = true, send = false, manage = false }
  }
  environment = var.environment
  project     = var.project
}

// =============================================================
// IAM
// =============================================================

# VM managed identity -> read/write the storage account's queues
module "role_queue_data_contributor" {
  source               = "../../../../modules/azure/role_assignment"
  scope                = module.storage.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = var.vm_identity_principal_id
}
