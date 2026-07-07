using '../main.bicep'

param location = 'switzerlandnorth'

param tags = {
  Application: 'EUVD'
  Environment: 'Production'
  Owner: 'Security'
  ManagedBy: 'Bicep'
}
