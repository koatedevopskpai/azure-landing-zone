# ADR-002: Private Endpoints over Service Endpoints

## Status

Accepted

## Context

Azure PaaS services (Storage, SQL, Key Vault, ACR, AKS) can be secured using either:

1. **Service Endpoints**: Expose the Azure service to a VNet by adding the VNet's identity to the service's firewall rules.
2. **Private Endpoints**: Deploy a network interface with a private IP in the VNet that connects to the Azure service.

## Decision

We will use **Private Endpoints** for all PaaS services.

## Rationale

| Factor | Private Endpoints | Service Endpoints | Verdict |
|--------|------------------|-------------------|---------|
| **Network isolation** | Service gets a private IP in the VNet; fully isolated from internet | Service retains public endpoint; VNet is just allowed through the firewall | Private Endpoint wins - no public exposure |
| **Data exfiltration prevention** | Traffic never leaves the Azure backbone; no internet path | Service endpoint traffic still goes through the service's public endpoint | Private Endpoint wins - exfiltration blocked |
| **Cross-region** | Works across regions | Service endpoints are regional (source VNet and service must be same region) | Private Endpoint wins for DR |
| **On-premises connectivity** | Accessible via ExpressRoute/VPN (private IP is routable) | Not accessible from on-premises (service endpoint is VNet-only) | Private Endpoint wins for hybrid |
| **Cost** | Private Endpoint is free; inbound data transfer charges apply | Free; no additional cost | Equivalent |
| **Complexity** | Requires Private DNS Zones for name resolution | Simpler - just enable on subnet and service | Service Endpoint wins on simplicity |

The critical factor for SecondWave is **data exfiltration prevention**. FCA/PRA regulations require that customer data cannot leave the Azure tenant. With Service Endpoints, a compromised application could copy data to a storage account in another tenant because the storage service still has a public endpoint. With Private Endpoints, the data path is entirely within the VNet - the only way out is through the Azure Firewall, which we control.

## Consequences

- **Positive**: True network isolation for all PaaS services; meets FCA/PRA data exfiltration requirements.
- **Positive**: Private DNS Zones integrate with Private Endpoint auto-registration for seamless resolution.
- **Negative**: Requires Private DNS Zone management (handled by the private-dns module).
- **Negative**: Not all Azure services support Private Endpoints yet (requires AzAPI for edge cases).

## Compliance Mapping

- **FCA SYSC 6.1.1**: Data security - Private Endpoints ensure data stays within the Azure backbone.
- **PRA SS2/21**: Operational resilience - Private Endpoints work across-region for DR scenarios.
- **UK GDPR Article 32**: Security of processing - Appropriate technical measures applied.

## References

- [Azure Private Endpoint documentation](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Service Endpoint limitations](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoints-overview#limitations)
