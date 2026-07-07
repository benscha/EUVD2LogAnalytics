// Log Analytics workspace that stores EUVD vulnerability data and backs Microsoft Sentinel.
param workspaceName string
param location string
param tags object

@description('Data retention in days for the workspace, per the project requirement.')
param retentionInDays int = 365

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      disableLocalAuth: true
    }
  }
}

output id string = workspace.id
output name string = workspace.name
output location string = workspace.location
