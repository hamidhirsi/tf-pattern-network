# Create resource group
resource "azurerm_resource_group" "main" {
  name     = "main-network-rg"
  location = var.location
  tags     = var.tags
}

# Create Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "this" {
  for_each = { for la in var.dependent_resources.logs.log_analytics : la.name => la }
  
  name                = each.value.name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Create Storage Account
resource "azurerm_storage_account" "this" {
  for_each = { for sa in var.dependent_resources.logs.storage_accounts : sa.name => sa }
  
  name                     = each.value.name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

# Create Event Hub Namespace
resource "azurerm_eventhub_namespace" "this" {
  for_each = { for eh in var.dependent_resources.logs.event_hubs : eh.namespace_name => eh }
  
  name                = each.value.namespace_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Standard"
  capacity            = 1
  tags                = var.tags
}

# Create Event Hub
resource "azurerm_eventhub" "this" {
  for_each = { for eh in var.dependent_resources.logs.event_hubs : eh.name => eh }
  
  name                = each.value.name
  namespace_id      = azurerm_eventhub_namespace.this[each.value.namespace_name].id
  partition_count     = 2
  message_retention   = 1
}

# Create Private DNS Zone
resource "azurerm_private_dns_zone" "this" {
  for_each = { for dns in var.dependent_resources.network.private_dns_zones : dns.name => dns }
  
  name                = each.value.name
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}