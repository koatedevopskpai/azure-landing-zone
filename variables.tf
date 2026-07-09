# ARCHITECTURE DECISION: All variables are explicit with descriptions. No sensitive defaults.
# The environments map drives dynamic spoke creation via for_each, avoiding code duplication
# across dev/staging/prod.

variable "tenant_id" {
  description = "Azure Entra ID tenant ID for SecondWave."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID for the landing zone."
  type        = string
}

variable "root_mg_name" {
  description = "Display name for the root Management Group (e.g., SecondWave)."
  type        = string
  default     = "SecondWave"
}

variable "environments" {
  description = "Map of environment configurations. Each key is a spoke name."
  type = map(object({
    management_group_name = string
    spoke_cidr            = string
    region                = string
    tags                  = map(string)
  }))
  default = {
    dev = {
      management_group_name = "Landing-Zones-Dev"
      spoke_cidr            = "10.1.0.0/16"
      region                = "uksouth"
      tags = {
        Environment = "Development"
        CostCenter  = "ENG-DEV"
        DataClass   = "Internal"
      }
    }
    staging = {
      management_group_name = "Landing-Zones-Staging"
      spoke_cidr            = "10.2.0.0/16"
      region                = "uksouth"
      tags = {
        Environment = "Staging"
        CostCenter  = "ENG-STG"
        DataClass   = "Confidential"
      }
    }
    prod = {
      management_group_name = "Landing-Zones-Prod"
      spoke_cidr            = "10.3.0.0/16"
      region                = "uksouth"
      tags = {
        Environment = "Production"
        CostCenter  = "ENG-PROD"
        DataClass   = "Restricted"
      }
    }
  }
}

variable "hub_vnet_cidr" {
  description = "CIDR block for the hub VNet."
  type        = string
  default     = "10.0.0.0/16"
}

variable "hub_subnet_prefixes" {
  description = "Subnet prefixes within the hub VNet."
  type = object({
    azure_firewall          = string
    bastion                 = string
    gateway                 = string
    management              = string
  })
  default = {
    azure_firewall = "10.0.1.0/24"
    bastion        = "10.0.2.0/24"
    gateway        = "10.0.3.0/24"
    management     = "10.0.4.0/24"
  }
}

variable "regions" {
  description = "Azure regions used for multi-region support (primary/DR)."
  type = object({
    primary   = string
    secondary = string
  })
  default = {
    primary   = "uksouth"
    secondary = "ukwest"
  }
}

variable "firewall_sku" {
  description = "Azure Firewall SKU. Use Premium for TLS inspection in regulated workloads."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku)
    error_message = "Firewall SKU must be Standard or Premium."
  }
}

variable "firewall_threat_intel_mode" {
  description = "Threat intelligence mode for Azure Firewall."
  type        = string
  default     = "Alert"

  validation {
    condition     = contains(["Alert", "Deny", "Off"], var.firewall_threat_intel_mode)
    error_message = "Valid values: Alert, Deny, Off."
  }
}

variable "bastion_sku" {
  description = "Azure Bastion SKU."
  type        = string
  default     = "Standard"
}

variable "log_analytics_retention_days" {
  description = "Data retention in days for Log Analytics."
  type        = number
  default     = 730
}

variable "ddos_protection_plan_enabled" {
  description = "Enable DDoS Network Protection Plan for the hub VNet."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Default tags applied to all resources."
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Project     = "SecondWave"
    Repo        = "azure-landing-zone"
    Compliance  = "FCA-PRA"
  }
}

variable "entra_groups" {
  description = "Entra ID groups with PIM eligibility configuration."
  type = map(object({
    display_name        = string
    description         = string
    pim_eligible        = bool
    pim_approval_required = bool
    pim_max_duration_hours = number
  }))
  default = {
    platform-admins = {
      display_name        = "Platform-Admins"
      description         = "Platform engineering team with full platform access."
      pim_eligible        = true
      pim_approval_required = true
      pim_max_duration_hours = 4
    }
    personal-lines = {
      display_name        = "Personal-Lines"
      description         = "Personal lines insurance value stream."
      pim_eligible        = true
      pim_approval_required = true
      pim_max_duration_hours = 8
    }
    commercial-lines = {
      display_name        = "Commercial-Lines"
      description         = "Commercial lines insurance value stream."
      pim_eligible        = true
      pim_approval_required = true
      pim_max_duration_hours = 8
    }
    data-analytics = {
      display_name        = "Data-Analytics"
      description         = "Data engineering and analytics team."
      pim_eligible        = true
      pim_approval_required = true
      pim_max_duration_hours = 8
    }
  }
}

variable "private_dns_zones" {
  description = "Private DNS zones to create for Private Link."
  type        = set(string)
  default = [
    "privatelink.blob.core.windows.net",
    "privatelink.table.core.windows.net",
    "privatelink.queue.core.windows.net",
    "privatelink.file.core.windows.net",
    "privatelink.sql.azuresynapse.net",
    "privatelink.database.windows.net",
    "privatelink.vaultcore.azure.net",
    "privatelink.azurecr.io",
    "privatelink.azmk8s.io",
    "privatelink.redis.cache.windows.net",
    "privatelink.servicebus.windows.net",
    "privatelink.eventgrid.azure.net",
  ]
}

variable "policy_enforce_private_endpoints" {
  description = "Enable Azure Policy to enforce Private Endpoints on all PaaS resources."
  type        = bool
  default     = true
}

variable "policy_deny_public_ip_on_nics" {
  description = "Enable Azure Policy to deny Public IP addresses on Network Interfaces."
  type        = bool
  default     = true
}

variable "policy_enforce_cmk" {
  description = "Enable Azure Policy to enforce Customer-Managed Keys on eligible resources."
  type        = bool
  default     = true
}

variable "policy_enforce_https_storage" {
  description = "Enable Azure Policy to enforce HTTPS-only storage accounts."
  type        = bool
  default     = true
}
