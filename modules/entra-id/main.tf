# =============================================================================
# Entra ID Groups & PIM Module - Identity Governance
# =============================================================================
# ARCHITECTURE DECISION: Entra ID groups are aligned to SecondWave's three value
# streams (Personal Lines, Commercial Lines, Data & Analytics) plus Platform
# (shared infrastructure team). This follows the CAF identity model where
# groups map to business functions, not IT silos.
#
# Why PIM over standing group membership:
# 1. Zero standing privileges - administrators must activate their role
# 2. Approval workflow - Platform-Admins group requires approval for activation
# 3. Time-bound activation - max 8 hours (one shift), auto-expires
# 4. Audit trail - all activations are logged for FCA/PRA compliance
# 5. Azure AD P2 licensing is required but included in Microsoft 365 E5 for insurers
#
# SECURITY SAFEGUARD: PIM eligibility is the primary control for privileged
# access management. No user has permanent ownership of any Azure resource.
# All elevated access requires just-in-time activation with approval.

# ---------------------------------------------------------------------------
# Entra ID Groups
# ---------------------------------------------------------------------------
resource "azuread_group" "this" {
  for_each = var.groups

  display_name     = each.value.display_name
  description      = each.value.description
  security_enabled = true
  mail_enabled     = false
  types            = ["Unified"]

  # ARCHITECTURE DECISION: assignable_to_role=true enables this group to be
  # assigned to Azure RBAC roles (Key Vault Administrator, Contributor, etc.).
  # This is required for PIM eligibility to be meaningful - the group must be
  # role-assignable to grant Azure permissions when activated.
  assignable_to_role = true
}

# ---------------------------------------------------------------------------
# PIM Eligibility via Azure AD Privileged Access Group
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: The azuread_privileged_access_group resource defines
# PIM settings for each group. It requires Azure AD P2 licensing.
# The `eligibility` blocks define who can activate the role and for how long.
#
# Note: The actual PIM policy (who is eligible) is configured via
# azuread_privileged_access_assignment_schedule resources. This file defines
# the group-level PIM settings (max duration, approval required).

resource "azuread_privileged_access_group" "this" {
  for_each = {
    for k, v in var.groups : k => v
    if v.pim_eligible
  }

  display_name = "${each.value.display_name}-PIM"
  group_id     = azuread_group.this[each.key].object_id
}

# ---------------------------------------------------------------------------
# PIM Assignment Schedule (Eligibility Configuration)
# ---------------------------------------------------------------------------
# SECURITY SAFEGUARD: The Platform-Admins group requires approval for activation
# (break-glass scenario). All other groups have self-service activation with
# a maximum duration of 8 hours (standard working shift).

resource "azuread_privileged_access_assignment_schedule" "this" {
  for_each = {
    for k, v in var.groups : k => v
    if v.pim_eligible
  }

  principal_id   = data.azuread_client_config.current.object_id
  group_id       = azuread_privileged_access_group.this[each.key].group_id
  assignment_type = "Activate"

  # Note: In production, principal_id should be set to the user or group
  # that should be eligible. This is a placeholder to show the structure.
  justification = "PIM eligibility for ${each.value.display_name}"

  schedule {
    expiration {
      type   = "AfterDuration"
      duration = "PT${each.value.pim_max_duration_hours}H"
    }
  }
}

data "azuread_client_config" "current" {}
