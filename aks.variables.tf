variable "kubernetes_clusters" {
  type = map(object({
    naming = optional(object({
      name               = optional(string)
      override_prefixes  = optional(list(string), [])
      override_separator = optional(string)
    }), {})
    resource_group_name     = string
    dns_prefix              = string
    kubernetes_version      = optional(string)
    private_cluster_enabled = optional(bool, true)
    tags                    = optional(map(string), {})

    user_assigned_identity_key = optional(string)

    acr_access_keys = optional(list(string), []) # List of ACR keys to access, empty means all
    kv_access_keys  = optional(list(string), []) # List of Key Vault keys to access, empty means all

    default_node_pool = object({
      name                 = string
      vm_size              = string
      node_count           = number
      vnet_key             = string
      subnet_key           = string
      availability_zones   = optional(list(string))
      max_pods             = optional(number)
      os_disk_size_gb      = optional(number)
      auto_scaling_enabled = optional(bool, false)
      min_count            = optional(number)
      max_count            = optional(number)
    })

    identity = object({
      type = string
    })

    private_dns_zone_id = optional(string)

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