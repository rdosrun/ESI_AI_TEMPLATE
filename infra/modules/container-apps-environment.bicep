@description('Container Apps managed environment name.')
param name string

@description('Azure region.')
param location string

@description('Log Analytics workspace name for Container Apps logs.')
param logAnalyticsWorkspaceName string

@description('Standard tags for ownership and cost tracking.')
param tags object = {}

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

// Business purpose: provides the managed runtime boundary for the API and keeps hosting operations simple.
resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: workspace.properties.customerId
        sharedKey: workspace.listKeys().primarySharedKey
      }
    }
  }
}

output environmentId string = environment.id
