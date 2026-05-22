@description('Application Insights component name.')
param name string

@description('Azure region.')
param location string

@description('Log Analytics workspace resource ID.')
param workspaceResourceId string

@description('Standard tags for ownership and cost tracking.')
param tags object = {}

// Business purpose: tracks API health, latency, errors, and adoption signals for stakeholder KPIs.
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceResourceId
  }
}

output connectionString string = appInsights.properties.ConnectionString
output instrumentationKey string = appInsights.properties.InstrumentationKey
