targetScope = 'resourceGroup'

@description('Short environment name from Azure Developer CLI, such as dev or test.')
param environmentName string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Optional Azure OpenAI or Azure AI Foundry endpoint. Leave blank until a model resource is approved.')
param azureOpenAiEndpoint string = ''

@description('Optional model deployment name for chat completion workflows. Leave blank until a deployment exists.')
param azureOpenAiDeploymentName string = ''

@description('Azure OpenAI API version used by future API code.')
param azureOpenAiApiVersion string = '2024-10-21'

@description('Enable Cosmos DB for NoSQL as a vector-capable skill registry for agent tool and skill lookup.')
param enableSkillRegistry bool = true

@description('Container image deployed by azd. azd supplies this value during deployment.')
param apiImageName string = ''

var workloadName = 'esi-ai'
var baseName = '${workloadName}-${environmentName}'
var tags = {
  'azd-env-name': environmentName
  workload: workloadName
  purpose: 'AI proof-of-concept starter kit'
}

module identity 'modules/managed-identity.bicep' = {
  name: 'managed-identity'
  params: {
    name: '${baseName}-api-id'
    location: location
    tags: tags
  }
}

module logs 'modules/log-analytics.bicep' = {
  name: 'log-analytics'
  params: {
    name: '${baseName}-logs'
    location: location
    tags: tags
  }
}

module insights 'modules/application-insights.bicep' = {
  name: 'application-insights'
  params: {
    name: '${baseName}-appi'
    location: location
    workspaceResourceId: logs.outputs.workspaceId
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    namePrefix: replace('${workloadName}${environmentName}', '-', '')
    location: location
    documentContainerName: 'uploaded-documents'
    principalId: identity.outputs.principalId
    tags: tags
  }
}

module search 'modules/search.bicep' = {
  name: 'search'
  params: {
    name: '${baseName}-search'
    location: location
    tags: tags
  }
}

module skillRegistry 'modules/cosmos-skill-registry.bicep' = if (enableSkillRegistry) {
  name: 'skill-registry'
  params: {
    namePrefix: replace('${workloadName}${environmentName}', '-', '')
    location: location
    principalId: identity.outputs.principalId
    tags: tags
  }
}

module keyVault 'modules/key-vault.bicep' = {
  name: 'key-vault'
  params: {
    namePrefix: replace('${workloadName}${environmentName}', '-', '')
    location: location
    principalId: identity.outputs.principalId
    tags: tags
  }
}

module registry 'modules/container-registry.bicep' = {
  name: 'container-registry'
  params: {
    namePrefix: replace('${workloadName}${environmentName}', '-', '')
    location: location
    principalId: identity.outputs.principalId
    tags: tags
  }
}

module acaEnv 'modules/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  params: {
    name: '${baseName}-aca-env'
    location: location
    logAnalyticsWorkspaceName: logs.outputs.workspaceName
    tags: tags
  }
}

module api 'modules/container-app.bicep' = {
  name: 'api-container-app'
  params: {
    name: '${baseName}-api'
    location: location
    environmentId: acaEnv.outputs.environmentId
    imageName: empty(apiImageName) ? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' : apiImageName
    managedIdentityId: identity.outputs.identityId
    registryServer: registry.outputs.loginServer
    appInsightsConnectionString: insights.outputs.connectionString
    storageAccountName: storage.outputs.storageAccountName
    documentContainerName: storage.outputs.documentContainerName
    searchEndpoint: search.outputs.searchEndpoint
    skillRegistryEndpoint: enableSkillRegistry ? skillRegistry!.outputs.accountEndpoint : ''
    skillRegistryDatabaseName: enableSkillRegistry ? skillRegistry!.outputs.databaseName : ''
    skillRegistryContainerName: enableSkillRegistry ? skillRegistry!.outputs.skillsContainerName : ''
    keyVaultUri: keyVault.outputs.vaultUri
    azureOpenAiEndpoint: azureOpenAiEndpoint
    azureOpenAiDeploymentName: azureOpenAiDeploymentName
    azureOpenAiApiVersion: azureOpenAiApiVersion
    tags: union(tags, {
      'azd-service-name': 'api'
    })
  }
}

output apiUrl string = api.outputs.fqdn
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.outputs.loginServer
output storageAccountName string = storage.outputs.storageAccountName
output documentContainerName string = storage.outputs.documentContainerName
output searchEndpoint string = search.outputs.searchEndpoint
output skillRegistryEndpoint string = enableSkillRegistry ? skillRegistry!.outputs.accountEndpoint : ''
output skillRegistryDatabaseName string = enableSkillRegistry ? skillRegistry!.outputs.databaseName : ''
output skillRegistryContainerName string = enableSkillRegistry ? skillRegistry!.outputs.skillsContainerName : ''
output keyVaultUri string = keyVault.outputs.vaultUri
