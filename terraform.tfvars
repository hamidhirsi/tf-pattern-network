subscription_id = "ef0f4d95-6d15-4eaa-b61a-81525fd20fbc"

location = "uksouth"

tags = {
  Environment = "Development"
  Project     = "NetworkPattern"
  Owner       = "Terraform"
}

dependent_resources = {
  logs = {
    log_analytics = [
      {
        name                = "centrallogs"
        resource_group_name = "main-network-rg"
      }
    ],
    storage_accounts = [
      {
        name                = "centraldiagnostics"
        resource_group_name = "main-network-rg"
      }
    ],
    event_hubs = [
      {
        name                = "centralevents"
        namespace_name      = "centraleventsns"
        resource_group_name = "main-network-rg"
      }
    ]
  },
  network = {
    private_dns_zones = [
      {
        name                = "privatelink.vaultcore.azure.net"
        resource_group_name = "main-network-rg"
      }
    ]
  }
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
    
    # Add private DNS zones for Key Vault integration
    private_dns_zones = [
      "privatelink.vaultcore.azure.net"
    ]

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
        service_endpoints = ["Microsoft.Sql", "Microsoft.Storage", "Microsoft.KeyVault"]

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
      },

      "private-endpoints" = {
        name             = "private-endpoints-subnet"
        address_prefixes = ["10.0.4.0/24"]
        

        network_security_group = {
          rules = [
            {
              name                         = "deny-inbound-internet"
              priority                     = 100
              direction                    = "Inbound"
              access                       = "Deny"
              protocol                     = "*"
              source_port_ranges           = ["*"]
              destination_port_ranges      = ["*"]
              source_address_prefixes      = ["Internet"]
              destination_address_prefixes = ["*"]
            }
          ]
        }
      }
    }
  }
}

key_vaults = {
  "main" = {
    naming = {
      override_prefixes = ["dev", "kv"]
      override_separator = "-"
    },
    resource_group_name = "main-network-rg"
    sku_name            = "standard"
    enabled_for_deployment          = true
    enabled_for_disk_encryption     = true
    enabled_for_template_deployment = true
    enable_rbac_authorization       = true
    public_network_access_enabled   = false
    soft_delete_retention_days      = 90
    purge_protection_enabled        = true
    tags = {}
    
    private_endpoints = {
      "endpoint1" = {

        resource_group_name = "main-network-rg"
        subnet_key = "private-endpoints"
        vnet_key   = "main"
        private_dns_zones = [
          "privatelink.vaultcore.azure.net"
        ]
        subresources = ["vault"]
        tags = {}
      }
    }
    
    network_acls = {
      default_action = "Deny"
      bypass         = "AzureServices"
      ip_rules       = []
    }
    
    diagnostic_settings = {
      enabled_logs = [
        {
          category_group = "allLogs"
        },
        {
          category_group = "audit"
        }
      ],
      metrics = [
        {
          category = "AllMetrics"
          enabled  = true
        }
      ],
      log_analytics_key = "centrallogs"
      storage_account_key = "centraldiagnostics"
      event_hub = {
        key = "centralevents"
        authorization_rule_name = "RootManageSharedAccessKey"
      }
    }
  }
}