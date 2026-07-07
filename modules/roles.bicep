// Role assignments for the Logic App's managed identity.
//
// Monitoring Contributor and Log Analytics Contributor are assigned at resource-group
// scope, as required by the project.
//
// Monitoring Metrics Publisher is assigned on the Data Collection Rule only. This role
// is not listed in the original requirements but is technically required: it is the
// only role that permits sending data through the Logs Ingestion API, which this
// project uses instead of the legacy (shared-key based) Data Collector API to remain
// fully secret-free. Without it, log ingestion fails with an authorization error.
param principalId string
param dcrName string

var monitoringContributorRoleId = '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
var logAnalyticsContributorRoleId = '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
var monitoringMetricsPublisherRoleId = '3913510d-42f4-4e42-8a64-420c390055eb'

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' existing = {
  name: dcrName
}

resource monitoringContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, monitoringContributorRoleId)
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringContributorRoleId)
  }
}

resource logAnalyticsContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, logAnalyticsContributorRoleId)
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', logAnalyticsContributorRoleId)
  }
}

resource monitoringMetricsPublisherAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(dataCollectionRule.id, principalId, monitoringMetricsPublisherRoleId)
  scope: dataCollectionRule
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisherRoleId)
  }
}
