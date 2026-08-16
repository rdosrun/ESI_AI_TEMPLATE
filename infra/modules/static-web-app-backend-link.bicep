@description('Existing Azure Static Web App name.')
param staticWebAppName string

@description('Azure resource ID of the Container App linked as the /api backend.')
param backendResourceId string

@description('Azure region containing the linked Container App.')
param backendRegion string

resource site 'Microsoft.Web/staticSites@2025-03-01' existing = {
  name: staticWebAppName
}

// Business purpose: keeps browser API calls on the authenticated Static Web Apps
// origin and prevents callers from spoofing the platform-provided user headers.
resource backend 'Microsoft.Web/staticSites/linkedBackends@2025-03-01' = {
  parent: site
  name: 'api'
  properties: {
    backendResourceId: backendResourceId
    region: backendRegion
  }
}

output linkedBackendId string = backend.id
