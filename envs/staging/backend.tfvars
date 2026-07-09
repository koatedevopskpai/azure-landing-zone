# ARCHITECTURE DECISION: Staging state is isolated from dev and prod.
# SECURITY SAFEGUARD: Staging uses a separate state file to prevent cross-environment
# state corruption during pre-production validation.

resource_group_name  = "rg-terraform-state"
storage_account_name = "sttfstate<random-suffix>"
container_name       = "tfstate"
key                  = "envs/staging/landing-zone.tfstate"
use_azuread_auth     = true
