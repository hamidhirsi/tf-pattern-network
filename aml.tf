locals {
  machine_learning_workspaces = {
    for ml_key, ml in var.machine_learning_workspaces : ml_key =>
    merge(ml, {
      name = coalesce(
        ml.naming.name,
        join(
          coalesce(ml.naming.override_separator, "-"),
          concat(ml.naming.override_prefixes, [ml_key])
        )
      )

      application_insights = ml.application_insights != null ? merge(ml.application_insights, {
        name = coalesce(
          try(ml.application_insights.name, null),
          join(
            var.naming.separator,
            concat(var.naming.prefixes, ["ml", ml_key, "insights"])
          )
        )
      }) : null

      private_endpoints = {
        for pe_key, private_endpoint in ml.private_endpoints : pe_key =>
        merge(private_endpoint, {
          name      = coalesce(private_endpoint.name, "ml-${ml_key}-pe-${pe_key}")
          location  = var.location
          subnet_id = azurerm_subnet.this["${private_endpoint.vnet_key}.${var.virtual_networks[private_endpoint.vnet_key].subnets[private_endpoint.subnet_key].name}"].id
          tags      = merge(var.tags, try(private_endpoint.tags, {}))

          private_dns_zone_group = length(private_endpoint.private_dns_zones) > 0 ? {
            name                 = "ml-${ml_key}-dns-group-${pe_key}"
            private_dns_zone_ids = [for dns_zone in private_endpoint.private_dns_zones : azurerm_private_dns_zone.this[dns_zone].id]
          } : null

          private_service_connection = length(private_endpoint.subresources) > 0 ? {
            name                 = "ml-${ml_key}-connection-${pe_key}"
            is_manual_connection = false
            request_message      = null
            subresource_names    = private_endpoint.subresources
          } : null
        })
      }
    })
  }
}

resource "azurerm_machine_learning_workspace" "this" {
  for_each = local.machine_learning_workspaces

  name                          = each.value.name
  location                      = var.location
  resource_group_name           = each.value.resource_group_name
  application_insights_id       = each.value.application_insights != null ? azurerm_application_insights.this[each.key].id : null
  key_vault_id                  = each.value.key_vault_key != null ? azurerm_key_vault.this[each.value.key_vault_key].id : null
  storage_account_id            = each.value.storage_account_key != null ? azurerm_storage_account.this[each.value.storage_account_key].id : null
  container_registry_id         = each.value.container_registry_key != null ? azurerm_container_registry.this[each.value.container_registry_key].id : null
  public_network_access_enabled = each.value.public_network_access == "Enabled" ? true : false
  tags                          = merge(var.tags, each.value.tags)

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_private_endpoint" "ml" {
  for_each = {
    for entry in flatten([
      for ml_key, ml in local.machine_learning_workspaces : [
        for pe_key, pe in ml.private_endpoints : {
          key                 = "${ml_key}.${pe_key}"
          name                = pe.name
          resource_group_name = pe.resource_group_name
          location            = pe.location
          subnet_id           = pe.subnet_id
          tags                = pe.tags
          ml_id               = azurerm_machine_learning_workspace.this[ml_key].id
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
    private_connection_resource_id = each.value.ml_id
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

resource "azurerm_application_insights" "this" {
  for_each = {
    for k, v in local.machine_learning_workspaces : k => v
    if v.application_insights != null
  }

  name                = each.value.application_insights.name
  location            = var.location
  resource_group_name = each.value.resource_group_name
  application_type    = "web"
  workspace_id        = each.value.application_insights.workspace_key != null ? azurerm_log_analytics_workspace.this[each.value.application_insights.workspace_key].id : null
  tags                = merge(var.tags, try(each.value.application_insights.tags, {}))
}


resource "azurerm_monitor_diagnostic_setting" "ml" {
  for_each = {
    for k, v in var.machine_learning_workspaces : k => v.diagnostic_settings
    if v.diagnostic_settings != null
  }

  name               = format("%s-diag", coalesce(var.machine_learning_workspaces[each.key].naming.name, "ml-${each.key}"))
  target_resource_id = azurerm_machine_learning_workspace.this[each.key].id

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