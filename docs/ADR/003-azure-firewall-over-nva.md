# ADR-003: Azure Firewall over Third-Party NVA

## Status

Accepted

## Context

SecondWave needs a central egress inspection point. The options are:

1. **Azure Firewall**: Microsoft-managed, cloud-native firewall as a service.
2. **Third-party Network Virtual Appliance (NVA)**: Palo Alto Networks, Zscaler, Check Point, or Fortinet running on Azure VMs or as a SaaS.

## Decision

We will use **Azure Firewall (Standard SKU for dev/staging, Premium SKU for prod)**.

## Rationale

| Factor | Azure Firewall | Third-Party NVA | Verdict |
|--------|---------------|-----------------|---------|
| **Management overhead** | Microsoft-managed; no OS patching, no HA configuration | Self-managed VMs; patching, HA, scaling, health probes | Azure Firewall wins |
| **Scalability** | Auto-scales with throughput; no capacity planning | Manual scale sets or cluster management | Azure Firewall wins |
| **FQDN filtering** | Built-in FQDN rules (application rules) | Requires URL filtering licenses (e.g., PAN DB) | Equivalent |
| **TLS inspection** | Premium SKU supports TLS termination | Mature TLS inspection in most NVAs | NVA wins for deep TLS |
| **Cost** | Fixed hourly cost; no licensing | VM costs + NVA license costs (often significant) | Azure Firewall wins |
| **Integration** | Native Azure Monitor, Sentinel, Policy, Diagnostics | Custom log integrations; Log Analytics agent required | Azure Firewall wins |
| **Threat intelligence** | Built-in Microsoft threat feed | Third-party threat feeds (PAN Wildfire, etc.) | Equivalent |
| **Multi-region** | Deploy per region; no central management plane | Central management (Panorama, FortiManager) | NVA wins for multi-region |

For a 350-person UK insurer, the management overhead of a third-party NVA cannot be justified. Azure Firewall provides 80% of the capability at 20% of the operational cost. The Premium SKU in production provides TLS inspection for regulated workloads.

## When to Revisit

- If SecondWave requires advanced TLS inspection across all environments (not just prod), we may need Premium SKU everywhere or an NVA.
- If Azure Firewall incurs significant egress data processing charges, an NVA with bring-your-own-license (BYOL) may be cheaper.
- If FCA/PRA specifically requires a certified NVA (e.g., Palo Alto for PCI DSS), we will reassess.

## Consequences

- **Positive**: Zero management overhead; native Azure integration; predictable costs.
- **Positive**: Premium SKU in prod satisfies FCA TLS inspection requirements.
- **Negative**: No central management console for multi-region (not relevant yet).
- **Negative**: Deep packet inspection is less mature than Palo Alto or Check Point.

## Compliance Mapping

- **FCA SYSC 6.1.2**: Monitoring - Azure Firewall logs feed directly into Sentinel via diagnostics.
- **PRA SS2/21**: Operational resilience - Firewall is zone-redundant (AZ 1, 2, 3).

## References

- [Azure Firewall feature comparison](https://learn.microsoft.com/en-us/azure/firewall/choose-firewall-sku)
- [Azure Firewall Premium features](https://learn.microsoft.com/en-us/azure/firewall/premium-features)
