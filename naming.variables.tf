variable "naming" {
  description = "Global naming convention: default prefixes (e.g. Terraform + resource domain) and separator"
  type = object({
    prefixes  = list(string)
    separator = string
  })
  default = {
    prefixes  = ["hamid", "project"]
    separator = "-"
  }
}