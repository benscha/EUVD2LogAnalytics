// EUVD to Microsoft Sentinel Vulnerability Intelligence Platform.
// Deploys a fully serverless, secret-free pipeline that pulls vulnerability data from
// the public EUVD API into a Log Analytics workspace and Microsoft Sentinel.
//
// PREREQUISITIES:
//  param alertEmail
//  param resourceNames
//  param deployRoleAssignments
//  param deploySentinelAnalyticsRules
//
// Deploy with:
//   az login
//   az account set --subscription <subscription-id-or-name>
//   az group create --subscription <subscription-id-or-name> --name rg-euvd-prod --location switzerlandnorth
//   az deployment group create --subscription <subscription-id-or-name> --resource-group rg-euvd-prod --template-file main.bicep --parameters parameters/prod.bicepparam
//
// Resource names are defined centrally in the resourceNames parameter below.
// Override this object from a bicepparam file if your Azure naming convention
// requires different names per environment.
targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = 'switzerlandnorth'

@description('Tags applied to every resource in this deployment.')
param tags object = {
  Application: 'EUVD'
  Environment: 'Production'
  Owner: 'Security'
  ManagedBy: 'Bicep'
}

@description('Email address that receives failure notifications from the Action Group.')
@minLength(3)
param alertEmail string = 'benjamin.zulliger@fhnw.ch'

@description('Central resource names for this deployment. Keep this aligned with the Azure naming convention.')
param resourceNames object = {
  managedIdentity: 'app-azs-EUVD'
  workspace: 'p-loa-securityhuntingenrichments-02'
  customTable: 'EUVD_CL'
  dataCollectionEndpoint: 'p-dce-euvd-prod'
  dataCollectionRule: 'p-dcr-euvd-prod'
  logicApp: 'p-lca-euvd-prod'
  logicAppDiagnosticSetting: 'p-diag-la-euvd-prod'
  appInsights: 'p-appi-euvd-prod'
  actionGroup: 'p-ag-euvd-prod'
  metricAlert: 'p-malert-euvd-logicapp-failure'
  sentinelOnboardingState: 'default'
  sentinelCriticalRuleSeed: 'p-senruleset-euvd-critical-vulnerabilities'
  sentinelExploitedRuleSeed: 'p-senruleset-euvd-exploited-vulnerabilities'
  sentinelNewCriticalRuleSeed: 'p-senruleset-euvd-new-critical-vulnerabilities'
}

@description('Deploy managed identity role assignments. Requires Owner or User Access Administrator permissions. Set to false only if the deploying account cannot create role assignments.')
param deployRoleAssignments bool = true

@description('Deploy Microsoft Sentinel analytics rules. Leave false during the first deployment if Sentinel has not finished onboarding the workspace yet.')
param deploySentinelAnalyticsRules bool = false

module identity 'modules/identity.bicep' = {
  name: 'deploy-identity'
  params: {
    identityName: resourceNames.managedIdentity
    location: location
    tags: tags
  }
}

module workspace 'modules/workspace.bicep' = {
  name: 'deploy-workspace'
  params: {
    workspaceName: resourceNames.workspace
    location: location
    tags: tags
  }
}

module tables 'modules/tables.bicep' = {
  name: 'deploy-tables'
  params: {
    tableName: resourceNames.customTable
    dataCollectionEndpointName: resourceNames.dataCollectionEndpoint
    dataCollectionRuleName: resourceNames.dataCollectionRule
    location: location
    tags: tags
    workspaceName: workspace.outputs.name
    workspaceId: workspace.outputs.id
  }
}

module appInsights 'modules/appinsights.bicep' = {
  name: 'deploy-appinsights'
  params: {
    appInsightsName: resourceNames.appInsights
    location: location
    tags: tags
    workspaceId: workspace.outputs.id
  }
}

module sentinel 'modules/sentinel.bicep' = {
  name: 'deploy-sentinel'
  params: {
    onboardingStateName: resourceNames.sentinelOnboardingState
    criticalRuleSeed: resourceNames.sentinelCriticalRuleSeed
    exploitedRuleSeed: resourceNames.sentinelExploitedRuleSeed
    newCriticalRuleSeed: resourceNames.sentinelNewCriticalRuleSeed
    deployAnalyticsRules: deploySentinelAnalyticsRules
    workspaceName: workspace.outputs.name
    tableName: tables.outputs.tableName
  }
}

module monitor 'modules/monitor.bicep' = {
  name: 'deploy-monitor'
  params: {
    actionGroupName: resourceNames.actionGroup
    tags: tags
    alertEmail: alertEmail
  }
}

module logicApp 'modules/logicapp.bicep' = {
  name: 'deploy-logicapp'
  params: {
    logicAppName: resourceNames.logicApp
    diagnosticSettingName: resourceNames.logicAppDiagnosticSetting
    location: location
    tags: tags
    identityId: identity.outputs.id
    workspaceId: workspace.outputs.id
    logsIngestionEndpoint: tables.outputs.logsIngestionEndpoint
    dcrImmutableId: tables.outputs.dcrImmutableId
    streamName: tables.outputs.streamName
  }
}

module alerts 'modules/alerts.bicep' = {
  name: 'deploy-alerts'
  params: {
    metricAlertName: resourceNames.metricAlert
    tags: tags
    logicAppId: logicApp.outputs.id
    actionGroupId: monitor.outputs.id
  }
}

module roles 'modules/roles.bicep' = if (deployRoleAssignments) {
  name: 'deploy-roles'
  params: {
    principalId: identity.outputs.principalId
    dcrName: tables.outputs.dcrName
  }
}

output resourceGroupName string = resourceGroup().name
output logicAppName string = logicApp.outputs.name
output workspaceName string = workspace.outputs.name
output managedIdentityName string = identity.outputs.name
