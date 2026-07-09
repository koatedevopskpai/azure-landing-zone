# Azure Firewall Recovery Runbook

## Objective

Recover Azure Firewall functionality in the event of a failure or misconfiguration. Target RTO: 2 hours, RPO: 15 minutes (diagnostic logs).

## Architecture

The Azure Firewall is deployed in the hub VNet (`vnet-hub-uksouth`) with:
- Zone-redundant deployment (AZ 1, 2, 3)
- Premium SKU in production
- Firewall Policy (centralised rule management)
- Diagnostics streaming to Log Analytics

## Prerequisites

- Platform-Admins PIM role activation (just-in-time)
- Azure CLI or Azure Portal access
- Terraform state accessible (see state-storage-failover.md if state is unavailable)

## Runbook Steps

### Scenario A: Firewall is unresponsive (no traffic passing)

1. **Verify firewall status**
   ```bash
   az network firewall show \
     --name afw-hub-uksouth \
     --resource-group rg-hub-network-uksouth \
     --query "provisioningState" --output tsv
   ```

2. **Check firewall health in Azure Monitor**
   - Navigate to: Azure Monitor > Firewalls > afw-hub-uksouth
   - Check: FirewallHealth metric (0 = healthy, 1 = degraded, 2 = unhealthy)
   - Check: Throughput metric (sudden drop indicates failure)

3. **Restart firewall** (if stuck in "Failed" state)
   ```bash
   az network firewall update \
     --name afw-hub-uksouth \
     --resource-group rg-hub-network-uksouth \
     --set "provisioningState=Updating"
   ```
   
   If the update command fails, deallocate and reallocate:
   ```bash
   # PowerShell equivalent: Stop-AzFirewall
   az network firewall stop \
     --name afw-hub-uksouth \
     --resource-group rg-hub-network-uksouth
   
   # Wait 2 minutes, then start
   sleep 120
   az network firewall start \
     --name afw-hub-uksouth \
     --resource-group rg-hub-network-uksouth
   ```

### Scenario B: Firewall Policy is misconfigured (traffic being incorrectly denied)

1. **Identify the problem via Log Analytics**
   ```kusto
   AzureDiagnostics
   | where Category == "AzureFirewallNetworkRule"
   | where action_s == "Deny"
   | where TimeGenerated > ago(30m)
   | summarize DeniedCount = count() by dst_ip_s, dst_port_d, protocol_s
   | order by DeniedCount desc
   ```

2. **Rollback policy to last known good version**
   ```bash
   # Download the last known good policy rules
   az network firewall policy show \
     --name afwp-hub-uksouth \
     --resource-group rg-hub-network-uksouth \
     --query "basePolicy.id" --output tsv
   
   # If using child policy, reset to base policy
   az network firewall policy update \
     --name afwp-hub-uksouth \
     --resource-group rg-hub-network-uksouth \
     --base-policy <known-good-policy-id>
   ```

3. **Emergency allow rule** (if prod is blocked)
   
   Add a temporary rule to restore traffic while troubleshooting:
   ```bash
   az network firewall policy rule-collection-group collection add-filter-collection \
     --policy-name afwp-hub-uksouth \
     --rcg-name EmergencyRules \
     --name emergency-deny-override \
     --action Allow \
     --rule-type Network \
     --priority 5000 \
     --rule-name allow-all-temp \
     --source-addresses "*" \
     --destination-addresses "*" \
     --destination-ports "*" \
     --protocols "Any"
   ```

4. **Commit corrected policy via Terraform** (permanent fix)
   ```bash
   terraform apply -target=module.hub_network.azurerm_firewall_policy_rule_collection_group.default
   ```

### Scenario C: Firewall is running but NAT Gateway has failed

1. **Verify NAT Gateway status**
   ```bash
   az network nat gateway show \
     --name nat-hub-uksouth \
     --resource-group rg-hub-network-uksouth \
     --query "provisioningState" --output tsv
   ```

2. **Failover to second NAT Gateway** (if deployed)
   
   Update spoke UDRs to point to the backup NAT Gateway's public IP.

### Scenario D: Complete hub VNet failure

1. **Activate DR spoke** (pre-provisioned in UK West)
   - Update DNS to point to DR workload
   - Provision new firewall in UK West
   - Update UDRs on DR spoke to use new firewall

2. **Create temporary hub** in UK West
   ```bash
   terraform apply -target=module.hub_network -var="regions.primary=ukwest"
   ```

## Testing

- Monthly: Firewall failover test (Scenario A)
- Quarterly: Full DR test (Scenario D) with compliance team observation

## RTO/RPO Targets

| Metric | Target | Current Capability |
|--------|--------|-------------------|
| RTO (stateful firewall) | 2 hours | 1 hour (re-deploy) |
| RPO (firewall rules) | 15 minutes | Real-time (Policy diagnostics) |

## References

- [Azure Firewall SLA](https://azure.microsoft.com/en-us/support/legal/sla/azure-firewall/v1_1/)
- [Azure Firewall FAQ](https://learn.microsoft.com/en-us/azure/firewall/firewall-faq)
