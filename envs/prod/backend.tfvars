# SECURITY SAFEGUARD: Production state is stored separately with strict RBAC.
# Only Platform-Admins (via PIM approval) can access this state file.
# The production state file is the most sensitive resource in the landing zone -
# it contains the entire infrastructure configuration and secrets references.

resource_group_name  = "rg-terraform-state"
storage_account_name = "sttfstate<random-suffix>"
container_name       = "tfstate"
key                  = "envs/prod/landing-zone.tfstate"
use_azuread_auth     = true
