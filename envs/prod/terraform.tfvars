# Production Environment - Full security guardrails
environments = {
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

# SECURITY SAFEGUARD: Premium firewall for TLS inspection in regulated workloads.
# FCA/PRA require demonstrable egress inspection for customer PII data.
firewall_sku = "Premium"

# SECURITY SAFEGUARD: Premium Bastion for advanced features (screen recording, RBAC)
bastion_sku = "Premium"

# SECURITY SAFEGUARD: 2-year log retention for FCA regulatory record-keeping (SYSC 6.1)
log_analytics_retention_days = 730

# DDoS protection enabled for availability (FCA/PRA operational resilience)
ddos_protection_plan_enabled = true

# All security policies enabled for production
policy_enforce_private_endpoints = true
policy_deny_public_ip_on_nics    = true
policy_enforce_cmk               = true
policy_enforce_https_storage     = true
