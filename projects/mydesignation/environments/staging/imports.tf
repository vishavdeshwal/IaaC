###############################################################################
# Import blocks (Terraform >= 1.5) — bind existing Azure resources to state.
#
# Run once:   terraform plan   -> confirm every line says "will be imported"
#             terraform apply   -> writes state (no resources created/destroyed)
# After a clean apply with no changes, you may delete this file (state is kept).
#
# sub = /subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92
###############################################################################

# ---------- Resource Group ----------
import {
  to = module.resource_group.azurerm_resource_group.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev"
}

# ---------- Virtual Networks + Subnets ----------
import {
  to = module.vnet_app.azurerm_virtual_network.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Network/virtualNetworks/staging-mydestination"
}
import {
  to = module.vnet_app.azurerm_subnet.this["default"]
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Network/virtualNetworks/staging-mydestination/subnets/default"
}
import {
  to = module.vnet_production.azurerm_virtual_network.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Network/virtualNetworks/production-vnet"
}
import {
  to = module.vnet_production.azurerm_subnet.this["public-subnet"]
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Network/virtualNetworks/production-vnet/subnets/public-subnet"
}
import {
  to = module.vnet_production.azurerm_subnet.this["private-app"]
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Network/virtualNetworks/production-vnet/subnets/private-app"
}
import {
  to = module.vnet_production.azurerm_subnet.this["private-db"]
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Network/virtualNetworks/production-vnet/subnets/private-db"
}

# ---------- Network Security Groups ----------
import {
  to = module.nsg_app.azurerm_network_security_group.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Network/networkSecurityGroups/staging-application-nsg"
}
import {
  to = module.nsg_testing1.azurerm_network_security_group.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Network/networkSecurityGroups/testing1-nsg"
}
import {
  to = module.nsg_testing1_715.azurerm_network_security_group.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Network/networkSecurityGroups/testing1nsg715"
}

# ---------- Public IPs ----------
import {
  to = module.pip_app.azurerm_public_ip.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Network/publicIPAddresses/staging-application-ip"
}
import {
  to = module.pip_mydestination.azurerm_public_ip.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Network/publicIPAddresses/staging-mydestination"
}

# ---------- NIC + NSG association ----------
import {
  to = module.nic_app.azurerm_network_interface.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Network/networkInterfaces/staging-application485"
}
import {
  to = module.nic_app.azurerm_network_interface_security_group_association.this[0]
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Network/networkInterfaces/staging-application485|/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Network/networkSecurityGroups/staging-application-nsg"
}

# ---------- SSH Public Keys ----------
import {
  to = module.ssh_app.azurerm_ssh_public_key.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Compute/sshPublicKeys/staging-application_key"
}
import {
  to = module.ssh_testing1.azurerm_ssh_public_key.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Compute/sshPublicKeys/testing1_key"
}

# ---------- Virtual Machine (OS disk imported inline) ----------
import {
  to = module.vm_app.azurerm_linux_virtual_machine.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Compute/virtualMachines/staging-application"
}

# ---------- Storage account + container + queue ----------
import {
  to = module.storage.azurerm_storage_account.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Storage/storageAccounts/mydesignation"
}
import {
  to = module.storage.azurerm_storage_container.this["staging-mydesignation-bucket"]
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Storage/storageAccounts/mydesignation/blobServices/default/containers/staging-mydesignation-bucket"
}
import {
  to = module.storage.azurerm_storage_queue.this["staging-mydesignation-queue"]
  id = "https://mydesignation.queue.core.windows.net/staging-mydesignation-queue"
}

# ---------- Service Bus namespace + auth rule ----------
import {
  to = module.servicebus_namespace.azurerm_servicebus_namespace.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.ServiceBus/namespaces/staging-mydesignation-bus"
}
import {
  to = module.servicebus_namespace.azurerm_servicebus_namespace_authorization_rule.this["webhook-app"]
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.ServiceBus/namespaces/staging-mydesignation-bus/authorizationRules/webhook-app"
}

# ---------- Service Bus queue + queue auth rules ----------
import {
  to = module.servicebus_queue.azurerm_servicebus_queue.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.ServiceBus/namespaces/staging-mydesignation-bus/queues/staging-mydesignation-queue"
}
import {
  to = module.servicebus_queue.azurerm_servicebus_queue_authorization_rule.this["send-only"]
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.ServiceBus/namespaces/staging-mydesignation-bus/queues/staging-mydesignation-queue/authorizationRules/send-only"
}
import {
  to = module.servicebus_queue.azurerm_servicebus_queue_authorization_rule.this["listen-only"]
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.ServiceBus/namespaces/staging-mydesignation-bus/queues/staging-mydesignation-queue/authorizationRules/listen-only"
}

# ---------- Role assignment (Storage Queue Data Contributor -> VM identity) ----------
import {
  to = module.role_queue_data_contributor.azurerm_role_assignment.this
  id = "/subscriptions/b9db5311-2d8c-47b1-940f-49d366af9c92/resourceGroups/rg-myd-mobileapp-dev/providers/Microsoft.Storage/storageAccounts/mydesignation/providers/Microsoft.Authorization/roleAssignments/02ca2974-87d3-497c-9b5f-750e49cf1ac5"
}
