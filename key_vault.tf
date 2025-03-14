locals {
  key_vaults = {
    for kv_key, key_vault in var.key_vaults : kv_key =>
    merge(key_vault, {
      private_endpoints = {
        for pe_key, private_endpoint in key_vault.private_endpoints : pe_key =>
        merge(private_endpoint, {
          name      = coalesce(private_endpoint.name, "kv-${kv_key}-pe-${pe_key}")
          location  = var.location
          subnet_id = azurerm_subnet.this["${private_endpoint.vnet_key}.${var.virtual_networks[private_endpoint.vnet_key].subnets[private_endpoint.subnet_key].name}"].id
          tags      = merge(var.tags, try(private_endpoint.tags, {}))

          private_dns_zone_group = length(private_endpoint.private_dns_zones) > 0 ? {
            name                 = "kv-${kv_key}-dns-group-${pe_key}"
            private_dns_zone_ids = [for dns_zone in private_endpoint.private_dns_zones : azurerm_private_dns_zone.this[dns_zone].id]
          } : null

          private_service_connection = length(private_endpoint.subresources) > 0 ? {
            name                 = "kv-${kv_key}-connection-${pe_key}"
            is_manual_connection = false
            request_message      = null
            subresource_names    = private_endpoint.subresources
          } : null
        })
      }
    })
  }
}

resource "azurerm_key_vault" "this" {
  for_each = var.key_vaults

  name = coalesce(
    each.value.naming.name,
    join(
      coalesce(each.value.naming.override_separator, "-"),
      concat(each.value.naming.override_prefixes, [each.key])
    )
  )

  location                        = var.location
  resource_group_name             = each.value.resource_group_name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  sku_name                        = each.value.sku_name
  enabled_for_deployment          = each.value.enabled_for_deployment
  enabled_for_disk_encryption     = each.value.enabled_for_disk_encryption
  enabled_for_template_deployment = each.value.enabled_for_template_deployment
  enable_rbac_authorization       = each.value.enable_rbac_authorization
  public_network_access_enabled   = each.value.public_network_access_enabled
  soft_delete_retention_days      = each.value.soft_delete_retention_days
  purge_protection_enabled        = each.value.purge_protection_enabled
  tags                            = merge(var.tags, each.value.tags)

  # Network ACLs for firewall configuration
  dynamic "network_acls" {
    for_each = each.value.network_acls != null ? [each.value.network_acls] : []

    content {
      bypass                     = network_acls.value.bypass
      default_action             = network_acls.value.default_action
      ip_rules                   = network_acls.value.ip_rules
      virtual_network_subnet_ids = []
    }
  }
}

resource "azurerm_private_endpoint" "key_vault" {
  for_each = {
    for entry in flatten([
      for kv_key, kv in local.key_vaults : [
        for pe_key, pe in kv.private_endpoints : {
          key                 = "${kv_key}.${pe_key}"
          name                = pe.name
          resource_group_name = pe.resource_group_name
          location            = pe.location
          subnet_id           = pe.subnet_id
          tags                = pe.tags
          kv_id               = azurerm_key_vault.this[kv_key].id
          dns_zone_ids        = pe.private_dns_zone_group != null ? [for dns_zone in pe.private_dns_zones : azurerm_private_dns_zone.this[dns_zone].id] : []
          has_dns_zones       = pe.private_dns_zone_group != null && length(pe.private_dns_zones) > 0
          dns_zone_group_name = pe.private_dns_zone_group != null ? pe.private_dns_zone_group.name : null
          connection_name     = pe.private_service_connection.name
          subresource_names   = pe.private_service_connection.subresource_names # Changed from subresources
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
    private_connection_resource_id = each.value.kv_id
    is_manual_connection           = false
    subresource_names              = each.value.subresource_names # Changed to match the variable name
  }

  dynamic "private_dns_zone_group" {
    for_each = each.value.has_dns_zones ? [1] : []

    content {
      name                 = each.value.dns_zone_group_name
      private_dns_zone_ids = each.value.dns_zone_ids
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  for_each = {
    for k, v in var.key_vaults : k => v.diagnostic_settings if v.diagnostic_settings != null
  }

  name               = format("%s-diag", coalesce(var.key_vaults[each.key].naming.name, "kv-${each.key}"))
  target_resource_id = azurerm_key_vault.this[each.key].id

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
  eventhub_authorization_rule_id = each.value.event_hub != null ? "${azurerm_eventhub_namespace.this["centraleventsns"].id}/authorizationRules/RootManageSharedAccessKey" : null
}
