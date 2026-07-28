resource "azurerm_container_app" "this" {
  name                         = var.name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = var.revision_mode

  dynamic "identity" {
    for_each = var.identity_type != null ? [var.identity_type] : []
    content {
      type = identity.value
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    dynamic "container" {
      for_each = var.containers
      content {
        name    = container.value.name
        image   = container.value.image
        cpu     = container.value.cpu
        memory  = container.value.memory
        command = container.value.command
      }
    }
  }

  dynamic "ingress" {
    for_each = var.ingress != null ? [var.ingress] : []
    content {
      allow_insecure_connections = ingress.value.allow_insecure_connections
      external_enabled           = ingress.value.external_enabled
      target_port                = ingress.value.target_port
      
      dynamic "traffic_weight" {
        for_each = ingress.value.traffic_weight != null ? [ingress.value.traffic_weight] : []
        content {
          percentage      = traffic_weight.value.percentage
          latest_revision = traffic_weight.value.latest_revision
        }
      }
    }
  }
  
  tags = var.tags

  lifecycle {
    ignore_changes = [
      template,
      secret,
      registry,
      workload_profile_name
    ]
  }
}
