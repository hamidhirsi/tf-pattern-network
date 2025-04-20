variable "subscription_id" {
  description = "The Azure subscription ID"
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "dependent_resources" {
  description = "External resources this module depends on but doesn't create"
  type = object({
    logs = object({
      log_analytics = list(object({
        name                = string
        resource_group_name = string
        subscription_id     = optional(string)
      }))
      storage_accounts = list(object({
        name                = string
        resource_group_name = string
        subscription_id     = optional(string)
      }))
      event_hubs = list(object({
        name                = string
        namespace_name      = string
        resource_group_name = string
        subscription_id     = optional(string)
      }))
    })
    network = object({
      private_dns_zones = list(object({
        name                = string
        resource_group_name = string
        subscription_id     = optional(string)
      }))
    })
  })
  default = {
    logs = {
      log_analytics    = []
      storage_accounts = []
      event_hubs       = []
    }
    network = {
      private_dns_zones = []
    }
  }
}

variable "virtual_networks" {
  description = "Map of virtual networks with their subnets and network security groups"
  type = map(object({
    name          = string
    address_space = list(string)
    dns_servers   = optional(list(string), [])
    tags          = optional(map(string), {})

    subnets = map(object({
      name              = string
      address_prefixes  = list(string)
      service_endpoints = optional(list(string), [])

      network_security_group = optional(object({
        name = optional(string)
        rules = list(object({
          name                         = string
          priority                     = number
          direction                    = string
          access                       = string
          protocol                     = string
          source_port_ranges           = list(string)
          destination_port_ranges      = list(string)
          source_address_prefixes      = list(string)
          destination_address_prefixes = list(string)
        }))
      }))
    }))
  }))
}