@description('Managed identity name.')
param name string

@description('Azure region.')
param location string

@description('Standard tags for ownership and cost tracking.')
param tags object = {}

// Business purpose: lets the API access Azure services without hardcoded passwords or keys.
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

output identityId string = identity.id
output clientId string = identity.properties.clientId
output principalId string = identity.properties.principalId
