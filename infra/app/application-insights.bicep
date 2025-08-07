@description('The name of the Application Insights component')
param name string

@description('The location where the component will be deployed')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('The resource ID of the Log Analytics workspace')
param workspaceResourceId string

@description('Whether to disable local authentication')
param disableLocalAuth bool = true

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceResourceId
    DisableLocalAuth: disableLocalAuth
  }
}

@description('The resource ID of the Application Insights component')
output resourceId string = applicationInsights.id

@description('The name of the Application Insights component')
output name string = applicationInsights.name

@description('The connection string of the Application Insights component')
output connectionString string = applicationInsights.properties.ConnectionString

@description('The instrumentation key of the Application Insights component')
output instrumentationKey string = applicationInsights.properties.InstrumentationKey