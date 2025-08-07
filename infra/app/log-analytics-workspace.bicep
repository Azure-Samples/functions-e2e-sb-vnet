@description('The name of the Log Analytics workspace')
param name string

@description('The location where the workspace will be deployed')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('Data retention in days')
param dataRetention int = 30

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    retentionInDays: dataRetention
    sku: {
      name: 'PerGB2018'
    }
  }
}

@description('The resource ID of the Log Analytics workspace')
output resourceId string = logAnalyticsWorkspace.id

@description('The name of the Log Analytics workspace')
output name string = logAnalyticsWorkspace.name