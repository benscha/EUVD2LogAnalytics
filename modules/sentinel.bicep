// Enables Microsoft Sentinel on the workspace and creates the three analytics rules
// from the project requirements: critical vulnerabilities, exploited vulnerabilities,
// and newly published critical vulnerabilities.
param onboardingStateName string
param criticalRuleSeed string
param exploitedRuleSeed string
param newCriticalRuleSeed string
param deployAnalyticsRules bool
param workspaceName string
param tableName string

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

resource sentinelOnboarding 'Microsoft.SecurityInsights/onboardingStates@2023-02-01-preview' = {
  name: onboardingStateName
  scope: workspace
  properties: {}
}

resource criticalVulnerabilitiesRule 'Microsoft.SecurityInsights/alertRules@2023-02-01-preview' = if (deployAnalyticsRules) {
  name: guid(workspace.id, criticalRuleSeed)
  scope: workspace
  kind: 'Scheduled'
  dependsOn: [
    sentinelOnboarding
  ]
  properties: {
    displayName: 'EUVD - Critical Vulnerabilities'
    description: 'Detects vulnerabilities ingested from EUVD with a CVSS score of 9 or higher.'
    severity: 'High'
    enabled: true
    query: '${tableName}\n| where CVSSScore >= 9'
    queryFrequency: 'PT1H'
    queryPeriod: 'P1D'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionEnabled: false
    suppressionDuration: 'PT1H'
    tactics: [
      'InitialAccess'
    ]
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: false
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
      }
    }
  }
}

resource exploitedVulnerabilitiesRule 'Microsoft.SecurityInsights/alertRules@2023-02-01-preview' = if (deployAnalyticsRules) {
  name: guid(workspace.id, exploitedRuleSeed)
  scope: workspace
  kind: 'Scheduled'
  dependsOn: [
    sentinelOnboarding
  ]
  properties: {
    displayName: 'EUVD - Exploited Vulnerabilities'
    description: 'Detects vulnerabilities ingested from EUVD that are flagged as actively exploited.'
    severity: 'High'
    enabled: true
    query: '${tableName}\n| where Exploited == true'
    queryFrequency: 'PT1H'
    queryPeriod: 'P1D'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionEnabled: false
    suppressionDuration: 'PT1H'
    tactics: [
      'InitialAccess'
    ]
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: false
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
      }
    }
  }
}

resource newCriticalVulnerabilitiesRule 'Microsoft.SecurityInsights/alertRules@2023-02-01-preview' = if (deployAnalyticsRules) {
  name: guid(workspace.id, newCriticalRuleSeed)
  scope: workspace
  kind: 'Scheduled'
  dependsOn: [
    sentinelOnboarding
  ]
  properties: {
    displayName: 'EUVD - Newly Published Critical Vulnerabilities'
    description: 'Detects vulnerabilities ingested from EUVD with a CVSS score of 9 or higher that were published within the last 24 hours.'
    severity: 'High'
    enabled: true
    query: '${tableName}\n| where CVSSScore >= 9 and PublishedDate >= ago(24h)'
    queryFrequency: 'PT1H'
    queryPeriod: 'P1D'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionEnabled: false
    suppressionDuration: 'PT1H'
    tactics: [
      'InitialAccess'
    ]
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: false
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
      }
    }
  }
}
