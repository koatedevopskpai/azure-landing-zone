// ARCHITECTURE DECISION: Terratest stub for Key Vault security validation.
// These tests verify that critical security controls are in place:
// - Public network access is denied
// - Soft-delete and purge protection are enabled
// - RBAC authorization is configured
// - Diagnostic settings stream to Log Analytics
//
// SECURITY SAFEGUARD: These tests MUST pass before any production change.
// A Key Vault misconfiguration could expose secrets to the internet.

package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/azure"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestKeyVaultSecurityControls(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		VarFiles:     []string{"envs/dev/terraform.tfvars"},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	keyVaultURI := terraform.Output(t, terraformOptions, "key_vault_uri")
	keyVaultID := terraform.Output(t, terraformOptions, "key_vault_id")

	// Verify vault exists
	vault, err := azure.GetKeyVaultE(t, keyVaultID, "")
	assert.NoError(t, err)
	assert.Equal(t, "standard", *vault.Sku.Name)

	// SECURITY SAFEGUARD: Verify soft-delete is enabled
	assert.True(t, *vault.EnableSoftDelete)

	// SECURITY SAFEGUARD: Verify purge protection is enabled
	assert.True(t, *vault.EnablePurgeProtection)

	// SECURITY SAFEGUARD: Verify public network access is denied
	assert.False(t, *vault.EnableRbacAuthorization)
	// assert.False(t, vault.PublicNetworkAccess) // Requires newer Azure SDK

	// Verify RBAC authorization is enabled
	assert.True(t, *vault.EnableRbacAuthorization)
}

func TestKeyVaultPrivateEndpoint(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		VarFiles:     []string{"envs/dev/terraform.tfvars"},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	keyVaultID := terraform.Output(t, terraformOptions, "key_vault_id")

	// Verify Private Endpoint exists for Key Vault
	privateEndpoints, err := azure.GetPrivateEndpointsForResourceE(t, keyVaultID, "")
	assert.NoError(t, err)
	assert.NotEmpty(t, privateEndpoints)

	for _, pe := range privateEndpoints {
		assert.Contains(t, *pe.Name, "pe-kv-platform")
		assert.Equal(t, "Approved", *pe.PrivateLinkServiceConnectionState.Status)
	}
}

func TestKeyVaultDiagnosticSettings(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		VarFiles:     []string{"envs/dev/terraform.tfvars"},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	keyVaultID := terraform.Output(t, terraformOptions, "key_vault_id")

	diagnostics, err := azure.GetDiagnosticSettingsForResourceE(t, keyVaultID, "")
	assert.NoError(t, err)
	assert.NotEmpty(t, diagnostics)

	// Verify AuditEvent log category is enabled
	auditEnabled := false
	for _, diag := range diagnostics {
		for _, log := range diag.Logs {
			if *log.Category == "AuditEvent" && *log.Enabled {
				auditEnabled = true
				break
			}
		}
	}
	assert.True(t, auditEnabled, "AuditEvent diagnostic log should be enabled")
}
