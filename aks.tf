locals {
  kubernetes_clusters = {
    for aks_key, aks in var.kubernetes_clusters : aks_key =>
    merge(aks, {
      name = coalesce(
        aks.naming.name,
        join(
          coalesce(aks.naming.override_separator, var.naming.separator),
          concat(
            length(aks.naming.override_prefixes) > 0
            ? aks.naming.override_prefixes
            : var.naming.prefixes,
            [aks_key]
          )
        )
      )
      private_endpoints = {
        for pe_key, private_endpoint in aks.private_endpoints : pe_key =>
        merge(private_endpoint, {
          name      = coalesce(private_endpoint.name, "aks-${aks_key}-pe-${pe_key}")
          location  = var.location
          subnet_id = azurerm_subnet.this["${private_endpoint.vnet_key}.${var.virtual_networks[private_endpoint.vnet_key].subnets[private_endpoint.subnet_key].name}"].id
          tags      = merge(var.tags, try(private_endpoint.tags, {}))

          private_dns_zone_group = length(private_endpoint.private_dns_zones) > 0 ? {
            name                 = "aks-${aks_key}-dns-group-${pe_key}"
            private_dns_zone_ids = [for dns_zone in private_endpoint.private_dns_zones : azurerm_private_dns_zone.this[dns_zone].id]
          } : null

          private_service_connection = length(private_endpoint.subresources) > 0 ? {
            name                 = "aks-${aks_key}-connection-${pe_key}"
            is_manual_connection = false
            request_message      = null
            subresource_names    = private_endpoint.subresources
          } : null
        })
      }
    })
  }
}

resource "azurerm_kubernetes_cluster" "this" {
  for_each = var.kubernetes_clusters

  name = coalesce(
    each.value.naming.name,
    join(
      coalesce(each.value.naming.override_separator, "-"),
      concat(each.value.naming.override_prefixes, [each.key])
    )
  )
  location                = var.location
  resource_group_name     = each.value.resource_group_name
  dns_prefix              = each.value.dns_prefix
  kubernetes_version      = each.value.kubernetes_version
  private_cluster_enabled = each.value.private_cluster_enabled
  private_dns_zone_id     = each.value.private_dns_zone_id
  tags                    = merge(var.tags, each.value.tags)

  default_node_pool {
    name           = each.value.default_node_pool.name
    vm_size        = each.value.default_node_pool.vm_size
    node_count     = each.value.default_node_pool.node_count
    vnet_subnet_id = azurerm_subnet.this["${each.value.default_node_pool.vnet_key}.${var.virtual_networks[each.value.default_node_pool.vnet_key].subnets[each.value.default_node_pool.subnet_key].name}"].id
    # zones                = each.value.default_node_pool.zones
    max_pods             = each.value.default_node_pool.max_pods
    os_disk_size_gb      = each.value.default_node_pool.os_disk_size_gb
    auto_scaling_enabled = each.value.default_node_pool.auto_scaling_enabled
    min_count            = each.value.default_node_pool.auto_scaling_enabled ? each.value.default_node_pool.min_count : null
    max_count            = each.value.default_node_pool.auto_scaling_enabled ? each.value.default_node_pool.max_count : null
  }

  identity {
    type = each.value.identity.type
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    dns_service_ip = "172.16.0.10"
    service_cidr   = "172.16.0.0/16"
  }
}

# Private Endpoints for AKS
resource "azurerm_private_endpoint" "aks" {
  for_each = {
    for entry in flatten([
      for aks_key, aks in local.kubernetes_clusters : [
        for pe_key, pe in aks.private_endpoints : {
          key                 = "${aks_key}.${pe_key}"
          name                = pe.name
          resource_group_name = pe.resource_group_name
          location            = pe.location
          subnet_id           = pe.subnet_id
          tags                = pe.tags
          aks_id              = azurerm_kubernetes_cluster.this[aks_key].id
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
    private_connection_resource_id = each.value.aks_id
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


resource "azurerm_user_assigned_identity" "aks-managed-identity" {
  name                = "aks-managed-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_role_assignment" "network_contributor" {
  scope                = var.scope
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks-managed-identity.principal_id
}


# Role assignments for AKS clusters to access ACRs
resource "azurerm_role_assignment" "aks_acr" {
  for_each = {
    for pair in flatten([
      for aks_key, aks in var.kubernetes_clusters : [
        # If acr_access_keys is empty, grant access to all ACRs
        # Otherwise, only grant access to the specified ACRs
        for acr_key in length(aks.acr_access_keys) == 0 ? keys(var.container_registries) : aks.acr_access_keys : {
          aks_key = aks_key
          acr_key = acr_key
          id      = "${aks_key}-${acr_key}"
        } if contains(keys(var.container_registries), acr_key)
      ]
    ]) : pair.id => pair
  }

  scope                = azurerm_container_registry.this[each.value.acr_key].id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.this[each.value.aks_key].kubelet_identity[0].object_id

  depends_on = [
    azurerm_kubernetes_cluster.this,
    azurerm_container_registry.this
  ]
}

# Role assignments for AKS clusters to access Key Vaults
resource "azurerm_role_assignment" "aks_kv" {
  for_each = {
    for pair in flatten([
      for aks_key, aks in var.kubernetes_clusters : [
        # If kv_access_keys is empty, grant access to all Key Vaults
        # Otherwise, only grant access to the specified Key Vaults
        for kv_key in length(aks.kv_access_keys) == 0 ? keys(var.key_vaults) : aks.kv_access_keys : {
          aks_key = aks_key
          kv_key  = kv_key
          id      = "${aks_key}-${kv_key}"
        } if contains(keys(var.key_vaults), kv_key)
      ]
    ]) : pair.id => pair
  }

  scope                = azurerm_key_vault.this[each.value.kv_key].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.this[each.value.aks_key].kubelet_identity[0].object_id

  depends_on = [
    azurerm_kubernetes_cluster.this,
    azurerm_key_vault.this
  ]
}

# Diagnostic settings for AKS
resource "azurerm_monitor_diagnostic_setting" "aks" {
  for_each = {
    for k, v in var.kubernetes_clusters : k => v.diagnostic_settings
    if v.diagnostic_settings != null
  }

  name               = format("%s-diag", coalesce(var.kubernetes_clusters[each.key].naming.name, "aks-${each.key}"))
  target_resource_id = azurerm_kubernetes_cluster.this[each.key].id

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