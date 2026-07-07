// Custom Log Analytics table for EUVD data, plus the Data Collection Endpoint (DCE) and
// Data Collection Rule (DCR) used to ingest it via the Logs Ingestion API.
//
// The Logs Ingestion API is used instead of the legacy Data Collector API because the
// legacy API requires a shared workspace key, which this project forbids. The Logs
// Ingestion API instead accepts Microsoft Entra ID (managed identity) authentication.
param tableName string
param dataCollectionEndpointName string
param dataCollectionRuleName string
param location string
param tags object
param workspaceName string
param workspaceId string

var streamName = 'Custom-${tableName}'

var columns = [
  { name: 'TimeGenerated', type: 'datetime' }
  { name: 'EUVDId', type: 'string' }
  { name: 'Description', type: 'string' }
  { name: 'PublishedDate', type: 'datetime' }
  { name: 'UpdatedDate', type: 'datetime' }
  { name: 'CVSSScore', type: 'real' }
  { name: 'CVSSVersion', type: 'string' }
  { name: 'EPSS', type: 'real' }
  { name: 'Vendor', type: 'string' }
  { name: 'Product', type: 'string' }
  { name: 'Aliases', type: 'string' }
  { name: 'References', type: 'string' }
  { name: 'Exploited', type: 'boolean' }
]

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

resource table 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  parent: workspace
  name: tableName
  properties: {
    schema: {
      name: tableName
      columns: columns
    }
  }
}

resource dataCollectionEndpoint 'Microsoft.Insights/dataCollectionEndpoints@2022-06-01' = {
  name: dataCollectionEndpointName
  location: location
  tags: tags
  properties: {
    networkAcls: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: dataCollectionRuleName
  location: location
  tags: tags
  dependsOn: [
    table
  ]
  properties: {
    dataCollectionEndpointId: dataCollectionEndpoint.id
    streamDeclarations: {
      '${streamName}': {
        columns: columns
      }
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: workspaceId
          name: 'lawDestination'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          streamName
        ]
        destinations: [
          'lawDestination'
        ]
        outputStream: streamName
        transformKql: 'source'
      }
    ]
  }
}

output tableName string = tableName
output streamName string = streamName
output dcrId string = dataCollectionRule.id
output dcrName string = dataCollectionRule.name
output dcrImmutableId string = dataCollectionRule.properties.immutableId
output logsIngestionEndpoint string = dataCollectionEndpoint.properties.logsIngestion.endpoint
