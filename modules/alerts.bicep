// Azure Monitor metric alert that fires when the daily Logic App run fails for any
// reason (EUVD API error, parsing error, or ingestion error), notifying the Action Group.
param metricAlertName string
param tags object
param logicAppId string
param actionGroupId string

resource logicAppRunFailureAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: metricAlertName
  location: 'global'
  tags: tags
  properties: {
    description: 'Fires when the EUVD ingestion Logic App has one or more failed runs in the evaluation window.'
    severity: 1
    enabled: true
    scopes: [
      logicAppId
    ]
    evaluationFrequency: 'PT1H'
    windowSize: 'P1D'
    targetResourceType: 'Microsoft.Logic/workflows'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'RunsFailedCriterion'
          metricName: 'RunsFailed'
          metricNamespace: 'Microsoft.Logic/workflows'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}
