@description('Container App name.')
param name string

@description('Azure region.')
param location string

@description('Container Apps managed environment resource ID.')
param environmentId string

@description('Container image to run.')
param imageName string

@description('User-assigned managed identity resource ID.')
param managedIdentityId string

@description('Azure Container Registry login server.')
param registryServer string

@description('Application Insights connection string.')
param appInsightsConnectionString string

@description('Storage account name for uploaded documents.')
param storageAccountName string

@description('Blob container name for uploaded documents.')
param documentContainerName string

@description('Azure AI Search endpoint.')
param searchEndpoint string

@description('Cosmos DB endpoint for agent skill registry vector lookup.')
param skillRegistryEndpoint string = ''

@description('Cosmos DB database name for agent skill registry.')
param skillRegistryDatabaseName string = ''

@description('Cosmos DB container name for individual agent skills.')
param skillRegistryContainerName string = ''

@description('Key Vault URI for future secrets.')
param keyVaultUri string

@description('Optional Azure OpenAI or Azure AI Foundry endpoint.')
param azureOpenAiEndpoint string = ''

@description('Optional Azure OpenAI deployment name.')
param azureOpenAiDeploymentName string = ''

@description('Azure OpenAI API version.')
param azureOpenAiApiVersion string = '2024-10-21'

@description('Standard tags for ownership and cost tracking.')
param tags object = {}

// Business purpose: runs the proof-of-concept API as a small, scalable container without managing servers.
resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8000
        transport: 'auto'
      }
      registries: [
        {
          server: registryServer
          identity: managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: imageName
          env: [
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
            {
              name: 'AZURE_STORAGE_ACCOUNT_NAME'
              value: storageAccountName
            }
            {
              name: 'AZURE_STORAGE_DOCUMENT_CONTAINER'
              value: documentContainerName
            }
            {
              name: 'AZURE_SEARCH_ENDPOINT'
              value: searchEndpoint
            }
            {
              name: 'AZURE_COSMOS_SKILL_REGISTRY_ENDPOINT'
              value: skillRegistryEndpoint
            }
            {
              name: 'AZURE_COSMOS_SKILL_REGISTRY_DATABASE'
              value: skillRegistryDatabaseName
            }
            {
              name: 'AZURE_COSMOS_SKILL_REGISTRY_CONTAINER'
              value: skillRegistryContainerName
            }
            {
              name: 'AZURE_KEY_VAULT_URI'
              value: keyVaultUri
            }
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: azureOpenAiEndpoint
            }
            {
              name: 'AZURE_OPENAI_DEPLOYMENT_NAME'
              value: azureOpenAiDeploymentName
            }
            {
              name: 'AZURE_OPENAI_API_VERSION'
              value: azureOpenAiApiVersion
            }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 2
        rules: [
          {
            name: 'http-scale'
            http: {
              metadata: {
                concurrentRequests: '20'
              }
            }
          }
        ]
      }
    }
  }
}

output fqdn string = 'https://${app.properties.configuration.ingress.fqdn}'
output containerAppId string = app.id
