locals {
  # Storage account names must be 3-24 chars, lowercase alphanumeric, globally unique.
  name = var.name_override != null ? var.name_override : lower(replace("${var.environment}${var.project}${var.name}", "-", ""))
  tags = merge(
    {
      Name        = local.name
      Environment = var.environment
      Project     = var.project
    },
    var.tags,
  )
}

resource "azurerm_storage_account" "this" {
  name                            = local.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = var.account_tier
  account_replication_type        = var.account_replication_type
  account_kind                    = var.account_kind
  access_tier                     = var.access_tier
  https_traffic_only_enabled      = var.https_traffic_only_enabled
  min_tls_version                 = var.min_tls_version
  allow_nested_items_to_be_public = var.allow_nested_items_to_be_public

  tags = local.tags
}

resource "azurerm_storage_container" "this" {
  for_each = var.containers

  name                  = each.key
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = each.value.access_type
}

resource "azurerm_storage_queue" "this" {
  for_each = toset(var.queues)

  name                 = each.value
  storage_account_name = azurerm_storage_account.this.name
}
