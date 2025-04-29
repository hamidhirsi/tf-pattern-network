subscription_id = "ef0f4d95-6d15-4eaa-b61a-81525fd20fbc"

location = "uksouth"

tags = {
  Environment = "Development"
  Project     = "AKS-ML-Pattern"
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
      # Existing zones
      {
        name                = "privatelink.vaultcore.azure.net"
        resource_group_name = "main-network-rg"
      },
      # New zones for AKS, ACR, ML
      {
        name                = "privatelink.azurecr.io"
        resource_group_name = "main-network-rg"
      },
      {
        name                = "privatelink.api.azureml.ms"
        resource_group_name = "main-network-rg"
      },
      {
        name                = "privatelink.notebooks.azure.net"
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

managed_identities = {
  "aks-identity" = {
    name                = "dev-aks-identity"
    resource_group_name = "main-network-rg"

    role_assignments = [
      { role_definition_name = "AcrPull" },
      { role_definition_name = "Key Vault Secrets User" },
      { role_definition_name = "Network Contributor" }
    ]
  }
}

kubernetes_clusters = {
  "main" = {
    naming = {
      override_prefixes  = ["dev", "aks"]
      override_separator = "-"
    }
    resource_group_name     = "main-network-rg"
    dns_prefix              = "devaks"
    kubernetes_version      = "1.30.0"
    private_cluster_enabled = true

    user_assigned_identity_key = "aks-identity"
    # # Example: Explicit access configuration (optional)
    # # If omitted, access is granted to all ACRs and Key Vaults
    # acr_access_keys = ["main"] # Grant access only to "main" ACR
    # kv_access_keys  = ["main"] # Grant access only to "main" Key Vault

    default_node_pool = {
      name                 = "default"
      vm_size              = "Standard_DS2_v2"
      node_count           = 1
      vnet_key             = "main"
      subnet_key           = "private-endpoints"
      os_disk_size_gb      = 128
      auto_scaling_enabled = true
      min_count            = 1
      max_count            = 3
    }

    identity = {
      type = "SystemAssigned"
    }

    diagnostic_settings = {
      enabled_logs = [
        {
          category_group = "allLogs"
        }
      ],
      metrics = [
        {
          category = "AllMetrics"
          enabled  = true
        }
      ],
      log_analytics_key = "centrallogs"
    }
  }
}

# Azure Container Registry configuration
container_registries = {
  "main" = {
    naming = {
      name = "hamiddevacr12" # ACR names must be globally unique and alphanumeric only
    }
    resource_group_name = "main-network-rg"
    sku                 = "Premium"
    admin_enabled       = true

    private_endpoints = {
      "endpoint1" = {
        resource_group_name = "main-network-rg"
        subnet_key          = "private-endpoints"
        vnet_key            = "main"
        private_dns_zones = [
          "privatelink.azurecr.io"
        ]
        subresources = ["registry"]
      }
    }

    diagnostic_settings = {
      enabled_logs = [
        {
          category_group = "allLogs"
        }
      ],
      metrics = [
        {
          category = "AllMetrics"
          enabled  = true
        }
      ],
      log_analytics_key = "centrallogs"
    }
  }
}

# Azure Machine Learning Workspace configuration
machine_learning_workspaces = {
  "main" = {
    naming = {
      override_prefixes  = ["dev", "ml", "v2"]
      override_separator = "-"
    }
    resource_group_name    = "main-network-rg"
    storage_account_key    = "centraldiagnostics"
    key_vault_key          = "main"
    container_registry_key = "main"
    public_network_access  = "Disabled"

    private_endpoints = {
      "endpoint1" = {
        resource_group_name = "main-network-rg"
        subnet_key          = "private-endpoints"
        vnet_key            = "main"
        private_dns_zones = [
          "privatelink.api.azureml.ms"
        ]
        subresources = ["amlworkspace"]
      }
    }

    application_insights = {
      tags = {
        workspace_key = "centrallogs"
        environment   = "dev"
      }
    }

    diagnostic_settings = {
      enabled_logs = [
        {
          category_group = "allLogs"
        }
      ],
      metrics = [
        {
          category = "AllMetrics"
          enabled  = true
        }
      ],
      log_analytics_key = "centrallogs"
    }
  }
}

key_vaults = {
  "main" = {
    naming = {
      override_prefixes  = ["dev", "kv"]
      override_separator = "-"
    },
    resource_group_name             = "main-network-rg"
    sku_name                        = "standard"
    enabled_for_deployment          = true
    enabled_for_disk_encryption     = true
    enabled_for_template_deployment = true
    enable_rbac_authorization       = true
    public_network_access_enabled   = false
    soft_delete_retention_days      = 90
    purge_protection_enabled        = true
    tags                            = {}

    private_endpoints = {
      "endpoint1" = {

        resource_group_name = "main-network-rg"
        subnet_key          = "private-endpoints"
        vnet_key            = "main"
        private_dns_zones = [
          "privatelink.vaultcore.azure.net"
        ]
        subresources = ["vault"]
        tags         = {}
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
      log_analytics_key   = "centrallogs"
      storage_account_key = "centraldiagnostics"
      event_hub = {
        key                     = "centralevents"
        authorization_rule_name = "RootManageSharedAccessKey"
      }
    }
  }
}