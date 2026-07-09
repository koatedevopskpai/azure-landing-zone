# Dev Environment - Relaxed security posture for developer velocity
environments = {
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
}

# Dev uses Standard firewall (no TLS inspection to reduce cost)
firewall_sku = "Standard"

# Dev uses Standard Bastion (no advanced features needed)
bastion_sku = "Standard"

# Shorter retention for dev logs (90 days vs 730 for prod)
log_analytics_retention_days = 90
