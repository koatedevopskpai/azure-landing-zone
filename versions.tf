# ARCHITECTURE DECISION: Terraform ~> 1.9 enables structured assignment (for_each across environments),
# improved provider sensitivity, and robust test framework. AzureRM ~> 4.0 required for
# azurerm_management_group_subscription_association and azurerm_firewall_policy.
# AzAPI ~> 2.0 bridges gaps where AzureRM lacks coverage (e.g., PIM eligibility policies).
# AzureAD ~> 3.0 is required for PIM support via azuread_privileged_access_group.
# SECURITY SAFEGUARD: Pinning provider major versions prevents accidental upgrade of breaking changes
# in production pipelines. Dependabot/Renovate should pin minor/patch bumps.

terraform {
  required_version = "~> 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # ARCHITECTURE DECISION: Remote state via AzureRM backend. Storage account bootstrapped
  # by scripts/bootstrap-backend.sh with CMK, soft-delete, and public access blocked.
  # SECURITY SAFEGUARD: backend key per environment isolates blast radius - a compromised
  # dev state cannot expose prod infrastructure configuration.
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "sttfstate<random-suffix>"
  #   container_name       = "tfstate"
  #   key                  = "landing-zone.tfstate"
  #   use_azuread_auth     = true
  # }
}

provider "azurerm" {
  # ARCHITECTURE DECISION: OIDC auth via GitHub Actions federated identity (az login --federated-token)
  # eliminates static service principal secrets. The subscription_id and tenant_id are injected
  # via environment variables in CI/CD.
  # SECURITY SAFEGUARD: No hardcoded credentials in source. All provider auth is environment-driven.
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

provider "azuread" {
  # ARCHITECTURE DECISION: Using azuread provider for PIM and group management to decouple
  # Entra ID lifecycle from Azure subscription scope. PIM eligibility requires
  # azuread_privileged_access_group which is only available in azuread ~> 3.0.
}

provider "azapi" {
  # ARCHITECTURE DECISION: AzAPI used for resources not yet in AzureRM, such as
  # advanced Policy definitions and PIM configuration.
}
