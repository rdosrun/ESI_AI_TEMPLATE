@description('Lowercase storage account name prefix. The module adds a deterministic suffix.')
param namePrefix string

@description('Azure region.')
param location string

@description('Blob container for business documents uploaded during the proof of concept.')
param documentContainerName string = 'uploaded-documents'

@description('Managed identity principal ID that will read and write document blobs.')
param principalId string

@description('Standard tags for ownership and cost tracking.')
param tags object = {}

var storageName = toLower(take('${namePrefix}${uniqueString(resourceGroup().id)}', 24))

// Business purpose: stores the source documents that future RAG workflows will index and cite.
resource account 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  name: 'default'
  parent: account
}

resource documents 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  name: documentContainerName
  parent: blobService
  properties: {
    publicAccess: 'None'
  }
}

// Business purpose: grants the API only the document access it needs, using identity-based access.
resource blobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(account.id, principalId, 'Storage Blob Data Contributor')
  scope: account
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  }
}

output storageAccountName string = account.name
output storageAccountId string = account.id
output documentContainerName string = documents.name
