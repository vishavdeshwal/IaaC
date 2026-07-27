locals {
  name = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}"
  tags = merge(
    {
      Name        = local.name
      Environment = var.environment
      Project     = var.project
    },
    var.tags,
  )
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = local.name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.size
  admin_username      = var.admin_username

  network_interface_ids = var.network_interface_ids

  # Trusted Launch (null by default = not sent; set true for Trusted Launch VMs)
  secure_boot_enabled = var.secure_boot_enabled
  vtpm_enabled        = var.vtpm_enabled

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = var.os_disk_caching
    storage_account_type = var.os_disk_storage_account_type
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  dynamic "identity" {
    for_each = var.identity_type != null ? [1] : []
    content {
      type = var.identity_type
    }
  }

  tags = local.tags

  # Image version drifts as Azure publishes new builds; ignore to prevent
  # a forced replacement of an already-running VM (mirrors the AWS ec2 module).
  # boot_diagnostics / additional_capabilities are auxiliary blocks Azure
  # populates by default — ignore them so imported VMs aren't churned.
  lifecycle {
    ignore_changes = [
      source_image_reference,
      boot_diagnostics,
      additional_capabilities,
    ]
  }
}
