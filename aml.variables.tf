variable "machine_learning_workspaces" {
  type = map(object({
    naming = optional(object({
      name               = optional(string)
      override_prefixes  = optional(list(string), [])
      override_separator = optional(string)
    }), {})
    resource_group_name      = string
    application_insights_key = optional(string)
    key_vault_key            = optional(string)
    storage_account_key      = optional(string)
    container_registry_key   = optional(string)
    public_network_access    = optional(string, "Disabled")
    tags                     = optional(map(string), {})

    application_insights = optional(object({
      name          = optional(string)
      tags          = optional(map(string))
      workspace_key = optional(string)
    }), null)

    private_endpoints = optional(map(object({
      name                = optional(string)
      resource_group_name = string
      vnet_key            = string
      subnet_key          = string
      private_dns_zones   = optional(list(string), [])
      subresources        = optional(list(string), ["amlworkspace"])
      tags                = optional(map(string), {})
    })), {})

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
  default = {}
}