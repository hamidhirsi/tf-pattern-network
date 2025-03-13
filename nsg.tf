locals {
  # Filter subnets that have NSGs and add context
  network_security_groups = {
    for key, subnet in local.subnets : key => merge(
      subnet.network_security_group,
      {
        name                = coalesce(subnet.network_security_group.name, "${subnet.name}-nsg")
        subnet_key          = subnet.subnet_key
        subnet_name         = subnet.name
        vnet_key            = subnet.vnet_key
        vnet_name           = subnet.vnet_name
        resource_group_name = subnet.resource_group_name
      }
    ) if subnet.network_security_group != null
  }
}

resource "azurerm_network_security_group" "this" {
  for_each = local.network_security_groups

  name                = each.value.name
  location            = var.location
  resource_group_name = each.value.resource_group_name

  # Process each NSG rule
  dynamic "security_rule" {
    for_each = each.value.rules

    content {
      name      = security_rule.value.name
      priority  = security_rule.value.priority
      direction = security_rule.value.direction
      access    = security_rule.value.access
      protocol  = security_rule.value.protocol

      source_port_range            = length(security_rule.value.source_port_ranges) == 1 ? security_rule.value.source_port_ranges[0] : null
      source_port_ranges           = length(security_rule.value.source_port_ranges) > 1 ? security_rule.value.source_port_ranges : null
      destination_port_range       = length(security_rule.value.destination_port_ranges) == 1 ? security_rule.value.destination_port_ranges[0] : null
      destination_port_ranges      = length(security_rule.value.destination_port_ranges) > 1 ? security_rule.value.destination_port_ranges : null
      source_address_prefix        = length(security_rule.value.source_address_prefixes) == 1 ? security_rule.value.source_address_prefixes[0] : null
      source_address_prefixes      = length(security_rule.value.source_address_prefixes) > 1 ? security_rule.value.source_address_prefixes : null
      destination_address_prefix   = length(security_rule.value.destination_address_prefixes) == 1 ? security_rule.value.destination_address_prefixes[0] : null
      destination_address_prefixes = length(security_rule.value.destination_address_prefixes) > 1 ? security_rule.value.destination_address_prefixes : null
    }
  }

  tags = var.tags
}

# Associate NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.network_security_groups

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}