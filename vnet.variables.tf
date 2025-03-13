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