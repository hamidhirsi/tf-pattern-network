locals {
  # Flatten subnets from all networks
  subnets = {
    for entry in flatten([
      for net_key, net_value in var.virtual_networks : [
        for subnet_key, subnet_value in net_value.subnets : merge(
          subnet_value,
          {
            vnet_key            = net_key
            vnet_name           = net_value.name
            virtual_network_name = azurerm_virtual_network.this[net_key].name
            resource_group_name = azurerm_resource_group.main.name
            subnet_key          = subnet_key
          }
        )
      ]
    ]) : format("%s.%s", entry.vnet_key, entry.name) => entry
  }
}

resource "azurerm_subnet" "this" {
  for_each = local.subnets

  name                 = each.value.name
  resource_group_name  = each.value.resource_group_name
  virtual_network_name = each.value.virtual_network_name
  address_prefixes     = each.value.address_prefixes
  service_endpoints    = each.value.service_endpoints
}