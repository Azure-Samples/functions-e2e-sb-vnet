targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

var abbrs = loadJsonContent('./abbreviations.json')

// Optional parameters
param applicationInsightsName string = ''
param appServicePlanName string = ''
param serviceBusNamespaceName string = ''
param processorServiceName string = ''
param processorUserAssignedIdentityName string = ''
param logAnalyticsWorkspaceName string = ''
param resourceGroupName string = ''
param storageAccountName string = ''
param serviceBusQueueName string = ''

// Networking parameters - VNet is always enabled for this sample
param vNetName string = ''

@description('Id of the user identity to be used for testing and debugging. This is not required in production. Leave empty if not needed.')
param principalId string = deployer().objectId

var functionAppName = !empty(processorServiceName) ? processorServiceName : '${abbrs.webSitesFunctions}processor-${resourceToken}'
var deploymentStorageContainerName = 'app-package-${take(functionAppName, 32)}-${take(toLower(uniqueString(functionAppName, resourceToken)), 7)}'
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
var vnetName = !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// User assigned managed identity to be used by the Function App to access Azure resources
module processorUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.2' = {
  name: 'processorUserAssignedIdentity'
  scope: rg
  params: {
    name: !empty(processorUserAssignedIdentityName) ? processorUserAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}processor-${resourceToken}'
    location: location
    tags: tags
  }
}

// App service plan to host the function app
module appServicePlan 'br/public:avm/res/web/serverfarm:0.5.0' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    skuName: 'FC1' // Flex Consumption
    reserved: true
  }
}

// The function app
module processor './app/processor.bicep' = {
  name: 'processor'
  scope: rg
  params: {
    name: functionAppName
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.name
    appServicePlanId: appServicePlan.outputs.resourceId
    runtimeName: 'python'
    runtimeVersion: '3.11'
    storageAccountName: storage.outputs.name
    identityId: processorUserAssignedIdentity.outputs.resourceId
    identityClientId: processorUserAssignedIdentity.outputs.clientId
    appSettings: []
    virtualNetworkSubnetId: serviceVirtualNetwork.outputs.appSubnetID
    serviceBusQueueName: !empty(serviceBusQueueName) ? serviceBusQueueName : '${abbrs.serviceBusNamespacesQueues}${resourceToken}'
    serviceBusNamespaceFQDN: '${serviceBus.outputs.name}.servicebus.windows.net'
    deploymentStorageContainerName: deploymentStorageContainerName
  }
}

// Application Insights for monitoring and logging
module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.12.0' = {
  name: 'loganalytics'
  scope: rg
  params: {
    name: !empty(logAnalyticsWorkspaceName) ? logAnalyticsWorkspaceName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
    dataRetention: 30
  }
}

module monitoring 'br/public:avm/res/insights/component:0.4.1' = {
  name: 'monitoring'
  scope: rg
  params: {
    name: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    location: location
    tags: tags
    workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
    disableLocalAuth: true
    kind: 'web'
    applicationType: 'web'
    roleAssignments: [
      {
        principalId: processorUserAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Monitoring Metrics Publisher'
        principalType: 'ServicePrincipal'
      }
      {
        principalId: principalId
        roleDefinitionIdOrName: 'Monitoring Metrics Publisher'
        principalType: 'User'
      }
    ]
  }
}

// Storage account to host function code and for logging
module storage 'br/public:avm/res/storage/storage-account:0.29.0' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // Disable local authentication methods as per security policy
    dnsEndpointType: 'Standard'
    publicNetworkAccess: 'Disabled' // Always use private networking
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None'
    }
    blobServices: {
      containers: [
        {
          name: deploymentStorageContainerName
        }
      ]
    }
    minimumTlsVersion: 'TLS1_2'  // Enforcing TLS 1.2 for better security
    requireInfrastructureEncryption: false // Explicitly set to avoid read-only property issue
    
    // Built-in role assignments using AVM
    roleAssignments: [
      {
        principalId: processorUserAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Storage Blob Data Owner'
        principalType: 'ServicePrincipal'
      }
      {
        principalId: principalId
        roleDefinitionIdOrName: 'Storage Blob Data Owner'
        principalType: 'User'
      }
    ]
  }
}

// Service Bus namespace and queue for messaging
module serviceBus 'br/public:avm/res/service-bus/namespace:0.15.1' = {
  name: 'servicebus'
  scope: rg
  params: {
    name: !empty(serviceBusNamespaceName) ? serviceBusNamespaceName : '${abbrs.serviceBusNamespaces}${resourceToken}'
    location: location
    tags: tags
    skuObject: {
      name: 'Premium'
      capacity: 1
    }
    disableLocalAuth: true // Disable local authentication methods as per security policy
    publicNetworkAccess: 'Disabled' // Always use private networking
    queues: [
      {
        name: !empty(serviceBusQueueName) ? serviceBusQueueName : '${abbrs.serviceBusNamespacesQueues}${resourceToken}'
      }
    ]
    
    // Built-in role assignments
    roleAssignments: [
      {
        principalId: processorUserAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Azure Service Bus Data Receiver'
        principalType: 'ServicePrincipal'
      }
      {
        principalId: processorUserAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Azure Service Bus Data Sender'
        principalType: 'ServicePrincipal'
      }
      {
        principalId: principalId
        roleDefinitionIdOrName: 'Azure Service Bus Data Receiver'
        principalType: 'User'
      }
      {
        principalId: principalId
        roleDefinitionIdOrName: 'Azure Service Bus Data Sender'
        principalType: 'User'
      }
    ]
    
    // Private endpoints handled separately due to conditional module access limitations
  }
}

// VNet for private networking - always deployed
module serviceVirtualNetwork './app/vnet.bicep' = {
  name: 'serviceVirtualNetwork'
  scope: rg
  params: {
    vNetName: vnetName
    location: location
    tags: tags
  }
}

// Storage private endpoint - always deployed
module storagePrivateEndpoint './app/storage-PrivateEndpoint.bicep' = {
  name: 'storagePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: vnetName
    subnetName: 'st' // Match the subnet name from vnet.bicep
    resourceName: storage.outputs.name
  }
}

// Service Bus private endpoint - always deployed
module serviceBusPrivateEndpoint './app/servicebus-privateEndpoint.bicep' = {
  name: 'serviceBusPrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: vnetName
    subnetName: 'sb' // Match the subnet name from vnet.bicep
    sbNamespaceId: serviceBus.outputs.resourceId
  }
}

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.connectionString
output APPLICATIONINSIGHTS_NAME string = monitoring.outputs.name
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_CLIENT_ID string = processorUserAssignedIdentity.outputs.clientId
output SERVICE_API_IDENTITY_PRINCIPAL_ID string = processorUserAssignedIdentity.outputs.principalId
output SERVICE_API_NAME string = processor.outputs.SERVICE_PROCESSOR_NAME
output SERVICE_API_URI string = 'https://${processor.outputs.SERVICE_PROCESSOR_NAME}.azurewebsites.net'
output RESOURCE_GROUP string = rg.name

// Service Bus outputs for local development
output SERVICEBUS_CONNECTION__fullyQualifiedNamespace string = '${serviceBus.outputs.name}.servicebus.windows.net'
output SERVICEBUS_QUEUE_NAME string = !empty(serviceBusQueueName) ? serviceBusQueueName : '${abbrs.serviceBusNamespacesQueues}${resourceToken}'
