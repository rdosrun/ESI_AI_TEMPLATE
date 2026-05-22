@description('Log Analytics workspace name.')
param name string

@description('Azure region.')
param location string

@description('Standard tags for ownership and cost tracking.')
param tags object = {}

// Business purpose: centralizes platform logs so support teams can troubleshoot the proof of concept.
resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

output workspaceId string = workspace.id
output workspaceName string = workspace.name
output customerId string = workspace.properties.customerId
