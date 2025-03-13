resource "azurerm_resource_group" "main" {
  name     = "main-network-rg"
  location = var.location
  tags     = var.tags
}