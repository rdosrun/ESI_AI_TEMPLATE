@description('Lowercase Cosmos DB account name prefix. The module adds a deterministic suffix.')
param namePrefix string

@description('Azure region.')
param location string

@description('Managed identity principal ID that will read and write agent skills.')
param principalId string

@description('Standard tags for ownership and cost tracking.')
param tags object = {}

var accountName = toLower(take('${namePrefix}${uniqueString(resourceGroup().id)}skills', 44))
var databaseName = 'agent-skills'
var skillsContainerName = 'skills'
var groupsContainerName = 'skill-groups'

// Business purpose: stores agent skills, metadata, department/task groupings, and vector embeddings
// so an agent can find the right skill using natural language instead of hardcoded routing.
resource account 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: accountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
      {
        name: 'EnableNoSQLVectorSearch'
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  name: databaseName
  parent: account
  properties: {
    resource: {
      id: databaseName
    }
  }
}

// Business purpose: holds individual skills, their descriptions, routing metadata, and embeddings.
resource skills 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  name: skillsContainerName
  parent: database
  properties: {
    resource: {
      id: skillsContainerName
      partitionKey: {
        paths: [
          '/department'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
        vectorIndexes: [
          {
            path: '/embedding'
            type: 'quantizedFlat'
          }
        ]
      }
      vectorEmbeddingPolicy: {
        vectorEmbeddings: [
          {
            path: '/embedding'
            dataType: 'float32'
            distanceFunction: 'cosine'
            dimensions: 1536
          }
        ]
      }
      uniqueKeyPolicy: {
        uniqueKeys: [
          {
            paths: [
              '/skillId'
            ]
          }
        ]
      }
    }
  }
}

// Business purpose: groups skills into business-friendly bundles by department, task, and agent type.
resource groups 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  name: groupsContainerName
  parent: database
  properties: {
    resource: {
      id: groupsContainerName
      partitionKey: {
        paths: [
          '/department'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
    }
  }
}

// Business purpose: lets the API manage skill lookup records without storing Cosmos keys.
resource dataContributor 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  name: guid(account.id, principalId, 'Cosmos DB Built-in Data Contributor')
  parent: account
  properties: {
    principalId: principalId
    roleDefinitionId: '${account.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
    scope: account.id
  }
}

output accountEndpoint string = account.properties.documentEndpoint
output accountName string = account.name
output databaseName string = database.name
output skillsContainerName string = skills.name
output groupsContainerName string = groups.name
