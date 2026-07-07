// Workspace-based Application Insights, used for monitoring and diagnostics of the
// EUVD ingestion pipeline. Being workspace-based, all telemetry lands in the same
// Log Analytics workspace, so no separate instrumentation key or connection string
// needs to be issued, stored, or passed to any component.
param appInsightsName string
param location string
param tags object
param workspaceId string

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceId
    IngestionMode: 'LogAnalytics'
    DisableLocalAuth: true
  }
}

output id string = appInsights.id
output name string = appInsights.name
