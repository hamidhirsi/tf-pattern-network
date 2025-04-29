locals {
  role_assignments = flatten([
    for mi_key, mi in var.managed_identities : [
      for role in mi.role_assignments : {
        id        = "${mi_key}-${role.role_definition_name}"
        mi_key    = mi_key
        role_name = role.role_definition_name
      }
    ]
  ])
}

# Create the managed identities
resource "azurerm_user_assigned_identity" "this" {
  for_each = var.managed_identities

  name                = each.value.name
  location            = var.location
  resource_group_name = each.value.resource_group_name
  tags                = merge(var.tags, each.value.tags)

  depends_on = [
    azurerm_resource_group.main
  ]
}

# Create role assignments
resource "azurerm_role_assignment" "this" {
  for_each = {
    for role in local.role_assignments : role.id => role
  }

  principal_id         = azurerm_user_assigned_identity.this[each.value.mi_key].principal_id
  role_definition_name = each.value.role_name
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.managed_identities[each.value.mi_key].resource_group_name}"
}