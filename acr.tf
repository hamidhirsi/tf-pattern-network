locals {
  container_registries = {
    for acr_key, acr in var.container_registries : acr_key =>
    merge(acr, {
      name = coalesce(
        acr.naming.name,
        join(
          # if they’ve overridden the separator, use that, otherwise use our global one
          coalesce(acr.naming.override_separator, var.naming.separator),
          # if they’ve overridden prefixes, use those, otherwise use the global prefixes
          concat(
            length(acr.naming.override_prefixes) > 0
            ? acr.naming.override_prefixes
            : var.naming.prefixes,
            [acr_key]
          )
        )
      )

      private_endpoints = {
        for pe_key, private_endpoint in acr.private_endpoints : pe_key =>
        merge(private_endpoint, {
          name      = coalesce(private_endpoint.name, "acr-${acr_key}-pe-${pe_key}")
          location  = var.location
          subnet_id = azurerm_subnet.this["${private_endpoint.vnet_key}.${var.virtual_networks[private_endpoint.vnet_key].subnets[private_endpoint.subnet_key].name}"].id
          tags      = merge(var.tags, try(private_endpoint.tags, {}))

          private_dns_zone_group = length(private_endpoint.private_dns_zones) > 0 ? {
            name                 = "acr-${acr_key}-dns-group-${pe_key}"
            private_dns_zone_ids = [for dns_zone in private_endpoint.private_dns_zones : azurerm_private_dns_zone.this[dns_zone].id]
          } : null

          private_service_connection = length(private_endpoint.subresources) > 0 ? {
            name                 = "acr-${acr_key}-connection-${pe_key}"
            is_manual_connection = false
            request_message      = null
            subresource_names    = private_endpoint.subresources
          } : null
        })
      }
    })
  }
}

resource "azurerm_container_registry" "this" {
  for_each = local.container_registries

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  location            = var.location
  sku                 = each.value.sku
  admin_enabled       = each.value.admin_enabled
  tags                = merge(var.tags, each.value.tags)
}

resource "azurerm_private_endpoint" "acr" {
  for_each = {
    for entry in flatten([
      for acr_key, acr in local.container_registries : [
        for pe_key, pe in acr.private_endpoints : {
          key                 = "${acr_key}.${pe_key}"
          name                = pe.name
          resource_group_name = pe.resource_group_name
          location            = pe.location
          subnet_id           = pe.subnet_id
          tags                = pe.tags
          acr_id              = azurerm_container_registry.this[acr_key].id
          dns_zone_ids        = pe.private_dns_zone_group != null ? [for dns_zone in pe.private_dns_zones : azurerm_private_dns_zone.this[dns_zone].id] : []
          has_dns_zones       = pe.private_dns_zone_group != null && length(pe.private_dns_zones) > 0
          dns_zone_group_name = pe.private_dns_zone_group != null ? pe.private_dns_zone_group.name : null
          connection_name     = pe.private_service_connection.name
          subresource_names   = pe.private_service_connection.subresource_names
        }
      ]
    ]) : entry.key => entry
  }

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
  subnet_id           = each.value.subnet_id
  tags                = each.value.tags

  private_service_connection {
    name                           = each.value.connection_name
    private_connection_resource_id = each.value.acr_id
    is_manual_connection           = false
    subresource_names              = each.value.subresource_names
  }

  dynamic "private_dns_zone_group" {
    for_each = each.value.has_dns_zones ? [1] : []

    content {
      name                 = each.value.dns_zone_group_name
      private_dns_zone_ids = each.value.dns_zone_ids
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "acr" {
  for_each = {
    for k, v in var.container_registries : k => v.diagnostic_settings
    if v.diagnostic_settings != null
  }

  name               = format("%s-diag", coalesce(var.container_registries[each.key].naming.name, "acr-${each.key}"))
  target_resource_id = azurerm_container_registry.this[each.key].id

  dynamic "enabled_log" {
    for_each = each.value.enabled_logs != null ? each.value.enabled_logs : []

    content {
      category       = enabled_log.value.category
      category_group = enabled_log.value.category_group
    }
  }

  dynamic "metric" {
    for_each = each.value.metrics != null ? each.value.metrics : []

    content {
      category = metric.value.category
      enabled  = metric.value.enabled
    }
  }

  storage_account_id         = each.value.storage_account_key != null ? azurerm_storage_account.this[each.value.storage_account_key].id : null
  log_analytics_workspace_id = each.value.log_analytics_key != null ? azurerm_log_analytics_workspace.this[each.value.log_analytics_key].id : null

  eventhub_name                  = each.value.event_hub != null ? azurerm_eventhub.this[each.value.event_hub.key].name : null
  eventhub_authorization_rule_id = each.value.event_hub != null ? "${azurerm_eventhub_namespace.this["centraleventsns"].id}/authorizationRules/${each.value.event_hub.authorization_rule_name}" : null
}