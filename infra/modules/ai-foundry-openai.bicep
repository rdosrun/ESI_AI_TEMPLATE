@description('Azure region for the Azure AI Foundry / Azure OpenAI resource.')
param location string

@description('Environment name, such as dev, test, demo, or prod.')
param environmentName string

@description('Short project name used for resource naming.')
param projectName string = 'esi-ai'

@description('Model deployment name used by the application.')
param modelDeploymentName string = 'gpt-4o-mini'

@description('Model name to deploy.')
param modelName string = 'gpt-4o-mini'

@description('Model version. Change this if the selected model requires a specific version.')
param modelVersion string = '2024-07-18'

@description('Deployment SKU. GlobalStandard is a common starting point for model deployments when available.')
param deploymentSkuName string = 'GlobalStandard'

@description('Deployment capacity. Keep low for proof-of-concept usage.')
param deploymentCapacity int = 1

@description('Managed identity principal ID that should be allowed to call the deployed model.')
param principalId string

@description('Standard tags for ownership and cost tracking.')
param tags object = {}

var safeName = toLower(replace('${projectName}-${environmentName}', '-', ''))
var accountName = take('ai${safeName}${uniqueString(resourceGroup().id)}', 64)

// Business purpose: provides the approved model endpoint used by the API without storing API keys.
resource aiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: accountName
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
  }
}

// Business purpose: creates a named chat deployment the application can call consistently across environments.
resource chatDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aiAccount
  name: modelDeploymentName
  sku: {
    name: deploymentSkuName
    capacity: deploymentCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
  }
}

// Cognitive Services OpenAI User allows managed-identity inference calls without exposing API keys.
// Source: Microsoft Learn Azure built-in role ID for Cognitive Services OpenAI User.
resource openAiUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiAccount.id, principalId, 'Cognitive Services OpenAI User')
  scope: aiAccount
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  }
}

output endpoint string = aiAccount.properties.endpoint
output accountName string = aiAccount.name
output deploymentName string = chatDeployment.name
