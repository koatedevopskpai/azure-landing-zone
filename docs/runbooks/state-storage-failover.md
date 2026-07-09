# State Storage Failover Runbook

## Objective

Recover Terraform state storage in the event of an Azure region outage (UK South). Target RTO: 4 hours, RPO: 1 hour.

## Architecture

The Terraform state is stored in `sttfstate<random-suffix>` (GRS - geo-redundant storage). In case of UK South outage, Microsoft will fail over to UK West. This runbook handles the scenario where the failover is manual or the storage account is completely unavailable.

## Prerequisites

- Access to Platform-Admins PIM role (just-in-time activation required)
- Azure CLI installed (`az login`)
- Access to Key Vault containing the CMK for storage encryption
- Backups stored in `backups/` directory (created by automated pipeline)

## Runbook Steps

### Scenario A: UK South region is degraded (slow but functional)

1. **Verify storage account status**
   ```bash
   az storage account show \
     --name sttfstate<random-suffix> \
     --resource-group rg-terraform-state \
     --query "statusOfPrimary" --output tsv
   ```

2. **Download latest state files**
   ```bash
   az storage blob download \
     --account-name sttfstate<random-suffix> \
     --container-name tfstate \
     --name "landing-zone.tfstate" \
     --file "backups/landing-zone.tfstate"
   ```

3. **Continue operations** - The degraded primary is still functional.

### Scenario B: UK South region is unavailable (complete outage)

1. **Initiate storage account failover** (if using LRS or if GRS failover hasn't triggered)
   ```bash
   az storage account failover \
     --name sttfstate<random-suffix> \
     --resource-group rg-terraform-state
   ```

2. **Wait for failover completion** (typically 1-2 hours)
   ```bash
   az storage account show \
     --name sttfstate<random-suffix> \
     --query "statusOfSecondary" --output tsv
   ```

3. **Update backend configuration** to point to the new primary endpoint
   ```hcl
   # versions.tf - Updated after failover
   backend "azurerm" {
     resource_group_name  = "rg-terraform-state"
     storage_account_name = "sttfstate<random-suffix>"
     container_name       = "tfstate"
     key                  = "landing-zone.tfstate"
     use_azuread_auth     = true
     # No URL change needed - Azure handles DNS update
   }
   ```

4. **Run terraform init** to reconnect to state
   ```bash
   terraform init -reconfigure
   ```

5. **Verify state integrity**
   ```bash
   terraform state list
   ```

### Scenario C: Storage account is permanently lost

1. **Restore from backup** (requires pre-configured backup pipeline)
   ```bash
   # If backups are in another storage account (DR region)
   az storage blob copy start \
     --source-account-name sttfdrsuffix \
     --source-container tfstate-backups \
     --source-blob landing-zone.tfstate \
     --account-name sttfstate<new-suffix> \
     --destination-container tfstate \
     --destination-blob landing-zone.tfstate
   ```

2. **Re-bootstrap storage** using `scripts/bootstrap-backend.sh`

3. **Import existing resources** (last resort - requires full terraform import)
   ```bash
   terraform import module.hub_network.azurerm_virtual_network.this /subscriptions/.../vnet-hub-uksouth
   ```

## Prevention Measures

- **GRS enabled**: Geo-redundant storage automatically copies data to UK West.
- **Daily state backups**: Azure DevOps pipeline exports state to DR storage daily (RPO: 24h).
- **Soft-delete enabled**: 7-day retention for accidental deletion recovery.
- **RBAC restrictions**: Only Platform-Admins (via PIM) can delete/modify state.

## RTO/RPO Targets

| Metric | Target | Current Capability |
|--------|--------|-------------------|
| RTO (Recovery Time Objective) | 4 hours | 2 hours (GFS failover) |
| RPO (Recovery Point Objective) | 1 hour | 24 hours (daily backup) |

## References

- [Azure Storage disaster recovery](https://learn.microsoft.com/en-us/azure/storage/common/storage-disaster-recovery-guidance)
- [Terraform state in Azure Storage](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm)
