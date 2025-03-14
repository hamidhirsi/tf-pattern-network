variable "key_vaults" {
  type = map(object({
    naming = optional(object({
      name               = optional(string)
      override_prefixes  = optional(list(string), [])
      override_separator = optional(string)
    }), {})
    resource_group_name             = string
    sku_name                        = optional(string, "standard")
    enabled_for_deployment          = optional(bool, true)
    enabled_for_disk_encryption     = optional(bool, true)
    enabled_for_template_deployment = optional(bool, true)
    enable_rbac_authorization       = optional(bool, true)
    role_assignment_current_object  = optional(bool, false)
    public_network_access_enabled   = optional(bool, true)
    soft_delete_retention_days      = optional(number, 90)
    purge_protection_enabled        = optional(bool, true)
    tags                            = optional(map(string), {})

    private_endpoints = optional(map(object({
      name                          = optional(string)
      resource_group_name           = string
      vnet_key                      = string
      subnet_key                    = string
      custom_network_interface_name = optional(string)
      private_dns_zones             = optional(list(string), [])
      subresources                  = optional(list(string), [])
      tags                          = optional(map(string), {})
    })), {})

    network_acls = optional(object({
      bypass         = optional(string, "AzureServices")
      default_action = optional(string, "Allow")
      ip_rules       = optional(list(string))
    }), {})

    diagnostic_settings = optional(object({
      enabled_logs = optional(list(object({
        category       = optional(string)
        category_group = optional(string)
      })))

      metrics = optional(list(object({
        category = string
        enabled  = optional(bool, true)
      })))

      log_analytics_key   = optional(string)
      storage_account_key = optional(string)
      event_hub = optional(object({
        key                     = string
        authorization_rule_name = string
      }))
    }))
  }))
}