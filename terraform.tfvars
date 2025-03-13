subscription_id = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

location = "uksouth"

tags = {
  Environment = "Development"
  Project     = "NetworkInfrastructure"
  Owner       = "Terraform"
}

virtual_networks = {
  "main" = {
    name                = "main-vnet"
    resource_group_name = "main-network-rg"
    address_space       = ["10.0.0.0/16"]
    dns_servers         = ["168.63.129.16"]
    tags = {
      NetworkType = "Primary"
    }

    subnets = {
      "web" = {
        name              = "web-subnet"
        address_prefixes  = ["10.0.1.0/24"]
        service_endpoints = ["Microsoft.Web", "Microsoft.KeyVault"]

        network_security_group = {
          rules = [
            {
              name                         = "allow-http"
              priority                     = 100
              direction                    = "Inbound"
              access                       = "Allow"
              protocol                     = "Tcp"
              source_port_ranges           = ["*"]
              destination_port_ranges      = ["80", "443"]
              source_address_prefixes      = ["*"]
              destination_address_prefixes = ["*"]
            },
            {
              name                         = "allow-ssh"
              priority                     = 110
              direction                    = "Inbound"
              access                       = "Allow"
              protocol                     = "Tcp"
              source_port_ranges           = ["*"]
              destination_port_ranges      = ["22"]
              source_address_prefixes      = ["10.0.0.0/16"]
              destination_address_prefixes = ["*"]
            }
          ]
        }
      },
      "app" = {
        name             = "app-subnet"
        address_prefixes = ["10.0.2.0/24"]

        network_security_group = {
          rules = [
            {
              name                         = "allow-app-traffic"
              priority                     = 100
              direction                    = "Inbound"
              access                       = "Allow"
              protocol                     = "Tcp"
              source_port_ranges           = ["*"]
              destination_port_ranges      = ["8080", "8443"]
              source_address_prefixes      = ["10.0.1.0/24"]
              destination_address_prefixes = ["*"]
            }
          ]
        }
      },
      "data" = {
        name              = "data-subnet"
        address_prefixes  = ["10.0.3.0/24"]
        service_endpoints = ["Microsoft.Sql", "Microsoft.Storage"]

        network_security_group = {
          rules = [
            {
              name                         = "allow-sql"
              priority                     = 100
              direction                    = "Inbound"
              access                       = "Allow"
              protocol                     = "Tcp"
              source_port_ranges           = ["*"]
              destination_port_ranges      = ["1433"]
              source_address_prefixes      = ["10.0.2.0/24"]
              destination_address_prefixes = ["*"]
            }
          ]
        }
      }
    }
  }
}