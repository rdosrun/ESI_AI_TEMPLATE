@description('Azure Static Web App resource name.')
param name string

@description('Azure region supported by Static Web Apps. This can differ from the main workload region.')
param location string = 'eastus2'

@description('Standard tags for ownership and cost tracking.')
param tags object = {}

@allowed([
  'Free'
  'Standard'
])
@description('Static Web Apps plan. Standard is required to link the authenticated Container Apps backend.')
param skuName string = 'Standard'

// Business purpose: hosts the compiled Flutter web experience over managed HTTPS without
// coupling frontend releases to the FastMCP Container App lifecycle.
resource site 'Microsoft.Web/staticSites@2025-03-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuName
  }
  properties: {
    allowConfigFileUpdates: true
    publicNetworkAccess: 'Enabled'
    stagingEnvironmentPolicy: 'Disabled'
  }
}

output staticWebAppId string = site.id
output staticWebAppName string = site.name
output defaultHostname string = site.properties.defaultHostname
output url string = 'https://${site.properties.defaultHostname}'
