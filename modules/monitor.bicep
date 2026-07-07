// Action Group used to notify the security team by email when the ingestion pipeline fails.
param actionGroupName string
param tags object

@description('Email address that receives failure notifications. No other notification channel is configured.')
param alertEmail string

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'euvdalert'
    enabled: true
    emailReceivers: [
      {
        name: 'SecurityTeamEmail'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

output id string = actionGroup.id
