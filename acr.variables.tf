variable "container_registries" {
  type = map(object({
    naming = optional(object({
      name               = optional(string)
      override_prefixes  = optional(list(string), [])
      override_separator = optional(string)
    }), {})
    resource_group_name = string
    sku                 = optional(string, "Premium")
    admin_enabled       = optional(bool, false)
    tags                = optional(map(string), {})

    private_endpoints = optional(map(object({
      name                = optional(string)
      resource_group_name = string
      vnet_key            = string
      subnet_key          = string
      private_dns_zones   = optional(list(string), [])
      subresources        = optional(list(string), ["registry"])
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