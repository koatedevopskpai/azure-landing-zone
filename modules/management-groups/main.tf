# =============================================================================
# Management Groups Module - CAF Enterprise-Scale Hierarchy
# =============================================================================
# ARCHITECTURE DECISION: The CAF Management Group hierarchy is the foundation
# of Azure governance. It enables:
# 1. Policy inheritance - a policy assigned at Platform MG flows to all children
# 2. Subscription organisation - each LZ MG gets subscriptions from its value stream
# 3. Cost aggregation - Azure Cost Management groups by MG for chargeback
# 4. RBAC boundary - deny assignments at higher MGs prevent privilege escalation
#
# Why CAF over flat subscriptions: A 350-person insurer with 3 value streams needs
# policy separation between dev/test/prod. Flat subscriptions require duplicating
# policy assignments. CAF hierarchy assigns once at Platform, inherits everywhere.

# ARCHITECTURE DECISION: Root Management Group is created under the Tenant Root
# Group. The tenant_root_group_id is obtained from the azurerm_client_config.
# We do NOT manage the tenant root group itself to avoid accidental tenant-wide changes.

resource "azurerm_management_group" "root" {
  # ARCHITECTURE DECISION: The root MG uses the subscription ID as a suffix for
  # uniqueness. The display name is the organisation name (SecondWave).
  name         = var.root_mg_name
  display_name = var.root_mg_name
}

# ARCHITECTURE DECISION: Platform MG owns shared infrastructure (connectivity,
# identity, logging). All policy assignments for shared services live here.
resource "azurerm_management_group" "platform" {
  name         = "${var.root_mg_name}-Platform"
  display_name = "Platform"
  parent_management_group_id = azurerm_management_group.root.id
}

# ARCHITECTURE DECISION: Landing Zones MG is the parent for all workload
# environments. Separating by lifecycle phase (dev/staging/prod) allows
# graduated policy strictness - prod gets CMK enforcement, dev does not.
resource "azurerm_management_group" "landing_zones" {
  name         = "${var.root_mg_name}-Landing-Zones"
  display_name = "Landing Zones"
  parent_management_group_id = azurerm_management_group.root.id
}

# SECURITY SAFEGUARD: Environment-specific MGs. Dev has relaxed policies for
# developer velocity. Staging mirrors prod policies for pre-production validation.
# Prod has all security policies including CMK, PIM, and deny public access.
resource "azurerm_management_group" "environments" {
  for_each = var.environment_mgs

  name         = "${var.root_mg_name}-${each.value}"
  display_name = each.value
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

# ARCHITECTURE DECISION: Sandbox MG is intentionally ungoverned - it allows
# individual exploration without policy blockers. Users self-elevate via PIM.
resource "azurerm_management_group" "sandbox" {
  name         = "${var.root_mg_name}-Sandbox"
  display_name = "Sandbox"
  parent_management_group_id = azurerm_management_group.root.id
}

# ARCHITECTURE DECISION: Decommissioned MG is a "drain-stop-delete" holding bay.
# Subscriptions moved here trigger policy-driven cost alerts and eventual deletion.
resource "azurerm_management_group" "decommissioned" {
  name         = "${var.root_mg_name}-Decommissioned"
  display_name = "Decommissioned"
  parent_management_group_id = azurerm_management_group.root.id
}

# ARCHITECTURE DECISION: Associating the current subscription to the Platform MG
# ensures shared services (hub, logging, Key Vault) are governed by Platform-level
# policies.
resource "azurerm_management_group_subscription_association" "platform" {
  management_group_id = azurerm_management_group.platform.id
  subscription_id     = var.subscription_id
}
