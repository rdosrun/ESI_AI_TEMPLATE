@description('Lowercase registry name prefix. The module adds a deterministic suffix.')
param namePrefix string

@description('Azure region.')
param location string

@description('Managed identity principal ID used by Container Apps to pull images.')
param principalId string

@description('Standard tags for ownership and cost tracking.')
param tags object = {}

var registryName = toLower(take('${namePrefix}${uniqueString(resourceGroup().id)}acr', 50))

// Business purpose: stores the Docker image that represents the tested API build.
resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: registryName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

// Business purpose: lets the Container App pull approved images without registry passwords.
resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, principalId, 'AcrPull')
  scope: registry
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  }
}

output registryId string = registry.id
output registryName string = registry.name
output loginServer string = registry.properties.loginServer
