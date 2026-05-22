@description('Azure AI Search service name.')
param name string

@description('Azure region.')
param location string

@description('Standard tags for ownership and cost tracking.')
param tags object = {}

// Business purpose: prepares the environment for searchable documents and RAG retrieval.
// The free SKU keeps the starter proof of concept lightweight. Move to Basic/Standard for team pilots.
resource search 'Microsoft.Search/searchServices@2023-11-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'free'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'enabled'
    disableLocalAuth: false
  }
}

output searchEndpoint string = 'https://${search.name}.search.windows.net'
output searchServiceName string = search.name
