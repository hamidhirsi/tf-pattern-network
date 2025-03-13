resource "azurerm_virtual_network" "this" {
  for_each = var.virtual_networks

  name                = each.value.name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  address_space       = each.value.address_space
  dns_servers         = each.value.dns_servers
  tags                = merge(var.tags, each.value.tags)
}