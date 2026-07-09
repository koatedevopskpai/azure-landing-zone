# ARCHITECTURE DECISION: Each environment has a unique state file key. This
# isolates state between environments - a corrupted dev state does not impact
# prod. The storage account is bootstrapped via scripts/bootstrap-backend.sh.
# SECURITY SAFEGUARD: use_azuread_auth = true ensures RBAC authentication
# for state access, avoiding storage account keys.

resource_group_name  = "rg-terraform-state"
storage_account_name = "sttfstate<random-suffix>"
container_name       = "tfstate"
key                  = "envs/dev/landing-zone.tfstate"
use_azuread_auth     = true
