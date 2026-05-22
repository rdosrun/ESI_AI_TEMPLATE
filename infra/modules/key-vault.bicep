@description('Lowercase Key Vault name prefix. The module adds a deterministic suffix.')
param namePrefix string

@description('Azure region.')
param location string

@description('Managed identity principal ID for future secret reads.')
param principalId string

@description('Standard tags for ownership and cost tracking.')
param tags object = {}

// Business purpose: provides a governed location for future vendor keys, connection values, and rotation.
resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: toLower(take('${namePrefix}${uniqueString(resourceGroup().id)}kv', 24))
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enabledForTemplateDeployment: false
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
  }
}

// Business purpose: allows the API identity to read future secrets without exposing them in code.
resource secretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, principalId, 'Key Vault Secrets User')
  scope: vault
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
  }
}

output vaultUri string = vault.properties.vaultUri
output vaultName string = vault.name
