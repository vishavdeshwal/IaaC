terraform {
  required_version = ">= 1.5.0"

  backend "azurerm" {
    resource_group_name  = "rg-myd-mobileapp-dev"
    storage_account_name = "mydesignationtf17144"
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

data "azurerm_client_config" "current" {}

// =============================================================
// 1. Resource Group (Using Existing Dev RG due to permissions)
// =============================================================

data "azurerm_resource_group" "this" {
  name = "rg-myd-mobileapp-dev"
}

// =============================================================
// 2. Network
// =============================================================

# Virtual Network & Core Subnets
module "vnet" {
  source              = "../../../../modules/azure/virtual_network"
  name_override       = "prod-vnet"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  address_space       = var.vnet_address_space
  subnets             = var.vnet_subnets
  environment         = var.environment
  project             = var.project
}

# ACA Delegated Subnet
module "subnet_aca" {
  source               = "../../../../modules/azure/subnet"
  name                 = "aca-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = module.vnet.vnet_name
  address_prefixes     = var.aca_subnet_prefixes

  delegation = {
    name                       = "aca-delegation"
    service_delegation_name    = "Microsoft.App/environments"
    service_delegation_actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
  }
}

# Database Delegated Subnet
module "subnet_db" {
  source               = "../../../../modules/azure/subnet"
  name                 = "db-subnet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = module.vnet.vnet_name
  address_prefixes     = var.db_subnet_prefixes
  service_endpoints    = ["Microsoft.Storage"]

  delegation = {
    name                       = "fs-delegation"
    service_delegation_name    = "Microsoft.DBforPostgreSQL/flexibleServers"
    service_delegation_actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
  }
}

# Bastion Network Components (IP, NSG, NIC)
module "pip_bastion" {
  source              = "../../../../modules/azure/public_ip"
  name_override       = "prod-bastion-ip"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  environment         = var.environment
  project             = var.project
}

module "nsg_bastion" {
  source              = "../../../../modules/azure/network_security_group"
  name_override       = "prod-bastion-nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
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

module "nic_bastion" {
  source                        = "../../../../modules/azure/network_interface"
  name_override                 = "prod-bastion-nic"
  location                      = var.location
  resource_group_name           = data.azurerm_resource_group.this.name
  ip_configuration_name         = "ipconfig1"
  subnet_id                     = module.vnet.subnet_ids["bastion"]
  private_ip_address_allocation = "Dynamic"
  public_ip_address_id          = module.pip_bastion.id
  environment                   = var.environment
  project                       = var.project
}

resource "azurerm_network_interface_security_group_association" "bastion" {
  network_interface_id      = module.nic_bastion.id
  network_security_group_id = module.nsg_bastion.id
}

# Private DNS Zones for Database and Cache
module "dns_db" {
  source              = "../../../../modules/azure/private_dns_zone"
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.this.name
  virtual_network_links = {
    "prod-db-vnet-link" = module.vnet.vnet_id
  }
  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

module "dns_redis" {
  source              = "../../../../modules/azure/private_dns_zone"
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = data.azurerm_resource_group.this.name
  virtual_network_links = {
    "prod-redis-vnet-link" = module.vnet.vnet_id
  }
  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

// =============================================================
// 3. Compute
// =============================================================

# Bastion VM
module "ssh_bastion" {
  source              = "../../../../modules/azure/ssh_public_key"
  name_override       = "prod-bastion_key"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  public_key          = var.bastion_ssh_public_key
  environment         = var.environment
  project             = var.project
}

module "vm_bastion" {
  source                       = "../../../../modules/azure/linux_virtual_machine"
  name_override                = "prod-bastion"
  location                     = var.location
  resource_group_name          = data.azurerm_resource_group.this.name
  size                         = "Standard_B1s"
  admin_username               = "azureuser"
  admin_ssh_public_key         = var.bastion_ssh_public_key
  network_interface_ids        = [module.nic_bastion.id]
  os_disk_caching              = "ReadWrite"
  os_disk_storage_account_type = "StandardSSD_LRS"
  image_publisher              = "canonical"
  image_offer                  = "ubuntu-24_04-lts"
  image_sku                    = "server"
  image_version                = "latest"
  identity_type                = "SystemAssigned"
  secure_boot_enabled          = true
  vtpm_enabled                 = true
  environment                  = var.environment
  project                      = var.project
}

# Azure Container Apps
module "aca_env" {
  source                         = "../../../../modules/azure/container_app_environment"
  name                           = "prod-mydesignation-env"
  location                       = var.location
  resource_group_name            = data.azurerm_resource_group.this.name
  infrastructure_subnet_id       = module.subnet_aca.id
  internal_load_balancer_enabled = false

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

module "aca_app" {
  source                       = "../../../../modules/azure/container_app"
  name                         = "prod-mydesignation-app"
  container_app_environment_id = module.aca_env.id
  resource_group_name          = data.azurerm_resource_group.this.name
  revision_mode                = "Single"

  containers = [
    {
      name   = "api"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.5
      memory = "1Gi"
    }
  ]

  ingress = {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 80
    traffic_weight = {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

// =============================================================
// 4. Database & Cache
// =============================================================

# PostgreSQL Flexible Server
module "db" {
  source                 = "../../../../modules/azure/postgresql_flexible_server"
  name                   = "prod-mydesignation-pg"
  resource_group_name    = data.azurerm_resource_group.this.name
  location               = var.location
  delegated_subnet_id    = module.subnet_db.id
  private_dns_zone_id    = module.dns_db.id
  administrator_login    = var.db_admin_username
  administrator_password = var.db_admin_password
  
  # Configuration per user request
  sku_name   = "GP_Standard_D4ds_v4"
  storage_mb = 131072 # 128 GiB

  tags = {
    Environment = var.environment
    Project     = var.project
  }

  depends_on = [module.dns_db]
}

# Redis Cache
module "cache" {
  source              = "../../../../modules/azure/redis_cache"
  name                = "prod-mydesignation-redis"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  
  # Azure Cache for Redis (legacy) is retiring. Using Managed Redis.
  # Balanced_B1 is the smallest tier (approx 1-2GB RAM).
  sku_name            = "Balanced_B1"

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

module "pe_redis" {
  source              = "../../../../modules/azure/private_endpoint"
  name                = "prod-redis-pe"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  subnet_id           = module.vnet.subnet_ids["cache"]

  private_service_connection = {
    name                           = "prod-redis-psc"
    private_connection_resource_id = module.cache.id
    is_manual_connection           = false
    subresource_names              = ["redisEnterprise"]
  }

  private_dns_zone_group = {
    name                 = "redis-dns-group"
    private_dns_zone_ids = [module.dns_redis.id]
  }

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

// =============================================================
// 5. Storage
// =============================================================

module "storage" {
  source                          = "../../../../modules/azure/storage_account"
  name_override                   = "mydesignationprod"
  location                        = var.location
  resource_group_name             = data.azurerm_resource_group.this.name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  access_tier                     = "Hot"
  allow_nested_items_to_be_public = false
  containers = {
    "prod-mydesignation-bucket" = { access_type = "private" }
  }
  queues      = []
  environment = var.environment
  project     = var.project
}

// =============================================================
// 6. Messaging
// =============================================================

module "servicebus_namespace" {
  source              = "../../../../modules/azure/servicebus_namespace"
  name_override       = "prod-mydesignation-bus"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "Basic"
  authorization_rules = {}
  environment         = var.environment
  project             = var.project
}

module "servicebus_queue" {
  source        = "../../../../modules/azure/servicebus_queue"
  name_override = "prod-mydesignation-queue"
  namespace_id  = module.servicebus_namespace.id

  max_delivery_count                   = 10
  dead_lettering_on_message_expiration = true
  lock_duration                        = "PT1M"
  max_size_in_megabytes                = 1024
  default_message_ttl                  = "P14D"

  authorization_rules = {}
  environment         = var.environment
  project             = var.project
}

// =============================================================
// 7. IAM & Security
// =============================================================

module "role_assignment" {
  source               = "../../../../modules/azure/role_assignment"
  scope                = module.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.aca_app.identity_principal_id
}

// =============================================================
// 8. Azure Container Registry (ACR)
// =============================================================

module "acr" {
  source              = "../../../../modules/azure/container_registry"
  
  # ACR name must be globally unique and alphanumeric only
  name                = "prodmydesignationacr123"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "Basic"
  admin_enabled       = true

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}


// =============================================================
// 9. Key Vault (Secret Manager)
// =============================================================

module "key_vault" {
  source              = "../../../../modules/azure/key_vault"
  name                = "prodmydkv12345" # Must be globally unique, 3-24 chars
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku_name            = "standard"

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

module "kv_role_assignment" {
  source               = "../../../../modules/azure/role_assignment"
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.aca_app.identity_principal_id
}

module "kv_admin_role_assignment" {
  source               = "../../../../modules/azure/role_assignment"
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}
