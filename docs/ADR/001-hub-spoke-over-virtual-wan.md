# ADR-001: Hub-Spoke Topology over Azure Virtual WAN

## Status

Accepted

## Context

SecondWave is a 350-person UK insurer regulated by the FCA and PRA. We are designing the Azure network topology for our landing zone. Two primary options exist:

1. **Azure Virtual WAN (VWAN)**: Microsoft-managed global transit network with integrated routing, firewalling, and SD-WAN connectivity.
2. **Traditional Hub-Spoke**: Hub VNet with Azure Firewall, VNet peerings to spoke VNets, UDRs for forced tunnelling.

## Decision

We will use **Traditional Hub-Spoke** with Azure Firewall and VNet peerings.

## Rationale

| Factor | Hub-Spoke | Virtual WAN | Verdict |
|--------|-----------|-------------|---------|
| **Cost predictability** | Fixed hourly costs (Firewall, Bastion, NAT Gateway) | VWAN routing units + data processing charges scale with throughput | Hub-Spoke is more predictable for a 350-person org |
| **Operational complexity** | Well-understood by platform team; standard Terraform modules | Requires VWAN-specific knowledge; fewer engineers have deep VWAN experience | Hub-Spoke wins on team readiness |
| **FCA/PRA compliance** | Full control over egress inspection via Firewall rules | VWAN Secure Hub provides similar controls but with less granularity | Equivalent for compliance; Hub-Spoke is easier to audit |
| **Multi-region** | Manual VNet peering across regions; possible but cumbersome | Built-in global transit; superior for multi-region | VWAN wins for multi-region |
| **Hybrid connectivity** | ExpressRoute/VPN Gateway in hub; manual BGP config | Built-in SD-WAN integration; automated | VWAN wins for complex hybrid |
| **Third-party NVA** | Can insert NVAs (Palo Alto, Zscaler) behind Azure Load Balancer | Limited NVA support in VWAN Secure Hub | Hub-Spoke wins for NVA flexibility |

SecondWave operates in a single region (UK South) with a DR region (UK West). For the next 24 months, all workloads are single-region. The cost and complexity of VWAN cannot be justified.

## Consequences

- **Positive**: Lower monthly networking costs; easier team onboarding; full auditability for FCA/PRA.
- **Negative**: Multi-region expansion will require manual peering or a future migration to VWAN.
- **Trade-off**: If SecondWave acquires another insurer and needs global transit, we will reassess VWAN.

## Compliance Mapping

- **FCA SYSC 6.1.4**: Access controls - Hub-Spoke allows granular NSG + Firewall rules per spoke.
- **PRA SS2/21**: Operational resilience - Single-region supported; DR plan in docs/runbooks.

## References

- [Azure Hub-Spoke topology](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Azure Virtual WAN](https://learn.microsoft.com/en-us/azure/virtual-wan/virtual-wan-about)
