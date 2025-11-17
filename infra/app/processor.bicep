param name string
@description('Primary location for all resources & Flex Consumption Function App')
param location string = resourceGroup().location
param tags object = {}
param applicationInsightsName string = ''
param appServicePlanId string
param appSettings array = []
param runtimeName string 
param runtimeVersion string 
param serviceName string = 'processor'
param storageAccountName string
param virtualNetworkSubnetId string = ''
param instanceMemoryMB int = 2048
param maximumInstanceCount int = 100
param identityId string = ''
param identityClientId string = ''
param serviceBusQueueName string = ''
param serviceBusNamespaceFQDN string = ''
param deploymentStorageContainerName string

var kind = 'functionapp,linux'

resource stg 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

// Create a Flex Consumption Function App to host the processor
module processor 'br/public:avm/res/web/site:0.19.3' = {
  name: '${serviceName}-flex-consumption'
  params: {
    kind: kind
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    serverFarmResourceId: appServicePlanId
    managedIdentities: {
      userAssignedResourceIds: [
        identityId
      ]
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${stg.properties.primaryEndpoints.blob}${deploymentStorageContainerName}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: identityId
          }
        }
      }
      scaleAndConcurrency: {
        instanceMemoryMB: instanceMemoryMB
        maximumInstanceCount: maximumInstanceCount
      }
      runtime: {
        name: runtimeName
        version: runtimeVersion
      }
    }
    siteConfig: {
      alwaysOn: false
      appSettings: concat(appSettings, [
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__clientId'
          value: identityClientId
        }
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: stg.properties.primaryEndpoints.blob
        }
      ], [
        {
          name: 'ServiceBusConnection__fullyQualifiedNamespace'
          value: serviceBusNamespaceFQDN
        }
        {
          name: 'ServiceBusConnection__clientId'
          value: identityClientId
        }
        {
          name: 'ServiceBusConnection__credential'
          value: 'managedidentity'
        }
        {
          name: 'ServiceBusQueueName'
          value: serviceBusQueueName
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: identityClientId
        }
      ], !empty(applicationInsightsName) ? [
        {
          name: 'APPLICATIONINSIGHTS_AUTHENTICATION_STRING'
          value: 'ClientId=${identityClientId};Authorization=AAD'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.?properties.?ConnectionString ?? ''
        }
      ] : [])
    }
    virtualNetworkSubnetResourceId: !empty(virtualNetworkSubnetId) ? virtualNetworkSubnetId : null
  }
}

output SERVICE_PROCESSOR_NAME string = processor.outputs.name
output SERVICE_API_IDENTITY_PRINCIPAL_ID string = ''
