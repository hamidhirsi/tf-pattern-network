variable "managed_identities" {
  description = "Map of managed identities with their role assignments"
  type = map(object({
    name                = string
    resource_group_name = string
    tags                = optional(map(string), {})

    role_assignments = optional(list(object({
      role_definition_name = string
    })), [])
  }))
}