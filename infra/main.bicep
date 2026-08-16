targetScope = 'resourceGroup'

@description('Short environment name from Azure Developer CLI, such as dev or test.')
param environmentName string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Azure region for the Agent Builder Static Web App. Static Web Apps is available in a smaller set of regions than the other services.')
param agentBuilderLocation string = 'eastus2'

@description('Optional existing Azure OpenAI or Azure AI Foundry endpoint. Leave blank when deployAiModel is true.')
param azureOpenAiEndpoint string = ''

@description('Enable Cosmos DB for NoSQL as a vector-capable skill registry for agent tool and skill lookup.')
param enableSkillRegistry bool = true

@description('Container image deployed by azd. azd supplies this value during deployment.')
param apiImageName string = ''

@description('Whether to deploy Azure OpenAI / Azure AI Foundry model infrastructure.')
param deployAiModel bool = false

@description('Chat model deployment name used by the API.')
param azureOpenAiDeploymentName string = 'gpt-4o-mini'

@description('Chat model name.')
param azureOpenAiModelName string = 'gpt-4o-mini'

@description('Chat model version.')
param azureOpenAiModelVersion string = '2024-07-18'

@description('Azure OpenAI API version used by the application.')
param azureOpenAiApiVersion string = '2024-10-21'

@description('Comma-separated HTTPS hostnames that deployed API blocks may call. Wildcards may cover a subdomain suffix, for example *.example.com.')
param agentApiAllowedHosts string = ''

var workloadName = 'esi-ai'
// Azure resource naming rules are stricter than azd environment naming rules.
// Preserve the original environment name in tags, but normalize it for resource names.
var safeEnvironmentName = toLower(replace(environmentName, '_', '-'))
var baseName = '${workloadName}-${safeEnvironmentName}'
var compactNamePrefix = replace('${workloadName}${safeEnvironmentName}', '-', '')
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

module aiModel 'modules/ai-foundry-openai.bicep' = if (deployAiModel) {
  name: 'ai-foundry-openai'
  params: {
    location: location
    environmentName: safeEnvironmentName
    projectName: workloadName
    modelDeploymentName: azureOpenAiDeploymentName
    modelName: azureOpenAiModelName
    modelVersion: azureOpenAiModelVersion
    principalId: identity.outputs.principalId
    tags: tags
  }
}

var resolvedAzureOpenAiEndpoint = deployAiModel ? aiModel!.outputs.endpoint : azureOpenAiEndpoint

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    namePrefix: compactNamePrefix
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
    namePrefix: compactNamePrefix
    location: location
    principalId: identity.outputs.principalId
    tags: tags
  }
}

module keyVault 'modules/key-vault.bicep' = {
  name: 'key-vault'
  params: {
    namePrefix: compactNamePrefix
    location: location
    principalId: identity.outputs.principalId
    tags: tags
  }
}

module registry 'modules/container-registry.bicep' = {
  name: 'container-registry'
  params: {
    namePrefix: compactNamePrefix
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
    managedIdentityClientId: identity.outputs.clientId
    registryServer: registry.outputs.loginServer
    appInsightsConnectionString: insights.outputs.connectionString
    storageAccountName: storage.outputs.storageAccountName
    documentContainerName: storage.outputs.documentContainerName
    searchEndpoint: search.outputs.searchEndpoint
    skillRegistryEndpoint: enableSkillRegistry ? skillRegistry!.outputs.accountEndpoint : ''
    skillRegistryDatabaseName: enableSkillRegistry ? skillRegistry!.outputs.databaseName : ''
    skillRegistryContainerName: enableSkillRegistry ? skillRegistry!.outputs.skillsContainerName : ''
    architecturesContainerName: enableSkillRegistry ? skillRegistry!.outputs.architecturesContainerName : ''
    deploymentsContainerName: enableSkillRegistry ? skillRegistry!.outputs.deploymentsContainerName : ''
    keyVaultUri: keyVault.outputs.vaultUri
    azureOpenAiEndpoint: resolvedAzureOpenAiEndpoint
    azureOpenAiDeploymentName: azureOpenAiDeploymentName
    azureOpenAiApiVersion: azureOpenAiApiVersion
    corsAllowedOrigins: 'https://${agentBuilder.outputs.defaultHostname},http://localhost:8080'
    agentApiAllowedHosts: agentApiAllowedHosts
    tags: union(tags, {
      'azd-service-name': 'api'
    })
  }
}

module agentBuilder 'modules/static-web-app.bicep' = {
  name: 'agent-builder-static-web-app'
  params: {
    name: take('${baseName}-agent-builder-${uniqueString(resourceGroup().id)}', 60)
    location: agentBuilderLocation
    skuName: 'Standard'
    tags: union(tags, {
      'azd-service-name': 'agent-builder'
    })
  }
}

module agentBuilderBackendLink 'modules/static-web-app-backend-link.bicep' = {
  name: 'agent-builder-api-link'
  params: {
    staticWebAppName: agentBuilder.outputs.staticWebAppName
    backendResourceId: api.outputs.containerAppId
    backendRegion: location
  }
}

output apiUrl string = api.outputs.fqdn
output agentBuilderUrl string = agentBuilder.outputs.url
output agentBuilderHostname string = agentBuilder.outputs.defaultHostname
output agentBuilderName string = agentBuilder.outputs.staticWebAppName
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.outputs.loginServer
output storageAccountName string = storage.outputs.storageAccountName
output documentContainerName string = storage.outputs.documentContainerName
output searchEndpoint string = search.outputs.searchEndpoint
output skillRegistryEndpoint string = enableSkillRegistry ? skillRegistry!.outputs.accountEndpoint : ''
output skillRegistryDatabaseName string = enableSkillRegistry ? skillRegistry!.outputs.databaseName : ''
output skillRegistryContainerName string = enableSkillRegistry ? skillRegistry!.outputs.skillsContainerName : ''
output keyVaultUri string = keyVault.outputs.vaultUri
output azureOpenAiEndpoint string = resolvedAzureOpenAiEndpoint
output azureOpenAiDeploymentName string = azureOpenAiDeploymentName
output azureOpenAiApiVersion string = azureOpenAiApiVersion
output azureOpenAiAccountName string = deployAiModel ? aiModel!.outputs.accountName : ''
