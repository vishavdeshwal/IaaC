locals {
  name = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}"
}

resource "azurerm_servicebus_queue" "this" {
  name         = local.name
  namespace_id = var.namespace_id

  max_delivery_count                   = var.max_delivery_count
  dead_lettering_on_message_expiration = var.dead_lettering_on_message_expiration
  lock_duration                        = var.lock_duration
  max_size_in_megabytes                = var.max_size_in_megabytes
  default_message_ttl                  = var.default_message_ttl
}

resource "azurerm_servicebus_queue_authorization_rule" "this" {
  for_each = var.authorization_rules

  name     = each.key
  queue_id = azurerm_servicebus_queue.this.id
  listen   = each.value.listen
  send     = each.value.send
  manage   = each.value.manage
}
