param name string
param location string = resourceGroup().location
param tags object = {}
param applicationInsightsName string = ''
param appServicePlanId string
param appSettings object = {}
param runtimeName string 
param runtimeVersion string 
param serviceName string = 'processor'
param storageAccountName string
param virtualNetworkSubnetId string = ''
param serviceBusQueueName string = ''
param serviceBusNamespaceFQDN string = ''
param instanceMemoryMB int = 2048
param maximumInstanceCount int = 100
param identityId string = ''
param identityClientId string = ''
param deploymentStorageContainerName string

resource stg 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

resource functions 'Microsoft.Web/sites@2023-12-01' = {
  name: '${name}-functions'
  location: location
  tags: union(tags, { 'azd-service-name': serviceName })
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { 
      '${identityId}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlanId
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
    virtualNetworkSubnetId: virtualNetworkSubnetId
  }

  resource configAppSettings 'config' = {
    name: 'appsettings'
    properties: union(appSettings,
      {
        ServiceBusConnection__fullyQualifiedNamespace: serviceBusNamespaceFQDN
        ServiceBusConnection__clientId : identityClientId
        ServiceBusConnection__credential : 'managedidentity'
        AzureWebJobsStorage__accountName: stg.name
        AzureWebJobsStorage__clientId : identityClientId
        AzureWebJobsStorage__credential : 'managedidentity'
        ServiceBusQueueName: serviceBusQueueName
        APPLICATIONINSIGHTS_CONNECTION_STRING: !empty(applicationInsightsName) ? applicationInsights.properties.ConnectionString : ''
      })
  }
}

output SERVICE_PROCESSOR_NAME string = functions.name
output name string = functions.name
output uri string = 'https://${functions.properties.defaultHostName}'
output identityPrincipalId string = ''
