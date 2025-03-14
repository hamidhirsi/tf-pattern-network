locals {
  # Flatten the DNS zone links by network
  dns_zone_links = flatten([
    for vnet_key, vnet in var.virtual_networks : [
      for dns_zone in try(vnet.private_dns_zones, []) : {
        vnet_key = vnet_key
        vnet_name = vnet.name
        vnet_id = azurerm_virtual_network.this[vnet_key].id
        dns_zone = dns_zone
        resource_group_name = vnet.resource_group_name
        link_name = "${vnet.name}-link"
      }
    ]
  ])
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = {
    for idx, link in local.dns_zone_links : 
      "${link.vnet_key}.${link.dns_zone}" => link
  }
  
  name                  = each.value.link_name
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = each.value.dns_zone
  virtual_network_id    = each.value.vnet_id
  registration_enabled  = false
  
  tags = var.tags
}