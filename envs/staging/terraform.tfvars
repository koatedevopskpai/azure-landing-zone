# Staging Environment - Production-like security but with some flexibility
environments = {
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
}

# Staging uses Standard firewall (no TLS inspection)
firewall_sku = "Standard"

# Staging uses Standard Bastion
bastion_sku = "Standard"

# Staging retains logs for 1 year (FCA minimum for non-prod)
log_analytics_retention_days = 365
