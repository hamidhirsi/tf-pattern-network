locals {
  # Process Log Analytics workspaces
  log_analytics_workspaces = { 
    for la in var.dependent_resources.logs.log_analytics : la.name =>
    merge(la, {
      subscription_id = coalesce(la.subscription_id, data.azurerm_client_config.current.subscription_id)
    })
  }

  # Process Storage Accounts
  storage_accounts = { 
    for sa in var.dependent_resources.logs.storage_accounts : sa.name =>
    merge(sa, {
      subscription_id = coalesce(sa.subscription_id, data.azurerm_client_config.current.subscription_id)
    })
  }

  # Process Event Hubs
  event_hubs = { 
    for eh in var.dependent_resources.logs.event_hubs : eh.name =>
    merge(eh, {
      subscription_id = coalesce(eh.subscription_id, data.azurerm_client_config.current.subscription_id)
    })
  }

  # Process Private DNS Zones
  private_dns_zones = { 
    for dns in var.dependent_resources.network.private_dns_zones : dns.name =>
    merge(dns, {
      subscription_id = coalesce(dns.subscription_id, data.azurerm_client_config.current.subscription_id)
    })
  }
}

# Get current client configuration
data "azurerm_client_config" "current" {}