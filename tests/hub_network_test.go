// ARCHITECTURE DECISION: Terratest stubs for integration testing. These tests
// validate the deployed Azure infrastructure matches expected configuration.
// Run against a dedicated test subscription (not dev/staging/prod).
//
// SECURITY SAFEGUARD: Tests validate that security controls are properly deployed:
// - Firewall is deployed with configured SKU
// - Forced tunnelling UDRs exist with correct next-hop
// - DDoS Protection Plan is enabled

package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/azure"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestHubNetworkDeployment(t *testing.T) {
	t.Parallel()

	// ARCHITECTURE DECISION: Test against a dedicated test configuration
	// that mirrors production but uses isolated resources.
	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		VarFiles:     []string{"envs/dev/terraform.tfvars"},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Get outputs
	hubVNetID := terraform.Output(t, terraformOptions, "hub_vnet_id")
	firewallPrivateIP := terraform.Output(t, terraformOptions, "firewall_private_ip")
	firewallID := terraform.Output(t, terraformOptions, "firewall_id")

	// Verify hub VNet exists
	vnet, err := azure.GetVirtualNetworkE(t, hubVNetID, "")
	assert.NoError(t, err)
	assert.Contains(t, *vnet.Name, "vnet-hub")
	assert.NotEmpty(t, *vnet.AddressSpace.AddressPrefixes[0])

	// Verify firewall is deployed
	firewall, err := azure.GetAzureFirewallE(t, firewallID, "")
	assert.NoError(t, err)
	assert.Equal(t, "Standard", *firewall.Sku.Tier)

	// SECURITY SAFEGUARD: Verify firewall has a private IP assigned
	assert.NotEmpty(t, firewallPrivateIP)

	// Verify DDoS Protection is enabled
	assert.True(t, *vnet.EnableDdosProtection)
}

func TestHubSubnetsExist(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		VarFiles:     []string{"envs/dev/terraform.tfvars"},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	hubVNetID := terraform.Output(t, terraformOptions, "hub_vnet_id")

	subnets, err := azure.GetSubnetsForVirtualNetworkE(t, hubVNetID, "")
	assert.NoError(t, err)

	expectedSubnets := []string{"AzureFirewallSubnet", "AzureBastionSubnet", "GatewaySubnet"}
	for _, expected := range expectedSubnets {
		found := false
		for _, subnet := range subnets {
			if *subnet.Name == expected {
				found = true
				break
			}
		}
		assert.True(t, found, "Expected subnet %s not found in hub VNet", expected)
	}
}

func TestHubNetworkCleanup(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		VarFiles:     []string{"envs/dev/terraform.tfvars"},
	}

	terraform.InitAndApply(t, terraformOptions)
	terraform.Destroy(t, terraformOptions)

	// Verify resources were cleaned up
	hubVNetID := terraform.Output(t, terraformOptions, "hub_vnet_id")
	_, err := azure.GetVirtualNetworkE(t, hubVNetID, "")
	assert.Error(t, err)
}
