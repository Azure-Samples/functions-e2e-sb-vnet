targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@allowed(['australiaeast', 'eastasia', 'eastus', 'eastus2', 'northeurope', 'southcentralus', 'southeastasia', 'swedencentral', 'uksouth', 'westus2', 'eastus2euap'])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

param processorServiceName string = ''
param processorUserAssignedIdentityName string = ''
param applicationInsightsName string = ''
param appServicePlanName string = ''
param logAnalyticsName string = ''
param resourceGroupName string = ''
param storageAccountName string = ''
param serviceBusQueueName string = ''
param serviceBusNamespaceName string = ''
param vNetName string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
// Generate a unique function app name if one is not provided.
var appName = !empty(processorServiceName) ? processorServiceName : '${abbrs.webSitesFunctions}${resourceToken}'
// Generate a unique container name that will be used for deployments.
var deploymentStorageContainerName = 'app-package-${take(appName, 32)}-${take(resourceToken, 7)}'
@description('Id of the user or app to assign application roles')
param principalId string = ''
var principalIds = [processorUserAssignedIdentity.outputs.identityPrincipalId, principalId]

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// User assigned managed identity to be used by the Function App to reach storage and service bus
module processorUserAssignedIdentity './core/identity/userAssignedIdentity.bicep' = {
  name: 'processorUserAssignedIdentity'
  scope: rg
  params: {
    location: location
    tags: tags
    identityName: !empty(processorUserAssignedIdentityName) ? processorUserAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}processor-${resourceToken}'
  }
}

// The application backend
module processor './app/processor.bicep' = {
  name: 'processor'
  scope: rg
  params: {
    name: appName
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.10'
    storageAccountName: storage.outputs.name
    identityId: processorUserAssignedIdentity.outputs.identityId
    identityClientId: processorUserAssignedIdentity.outputs.identityClientId
    appSettings: {
    }
    virtualNetworkSubnetId: serviceVirtualNetwork.outputs.appSubnetID
    serviceBusQueueName: serviceBus.outputs.serviceBusQueueName
    serviceBusNamespaceFQDN: serviceBus.outputs.serviceBusNamespaceFQDN
    deploymentStorageContainerName: deploymentStorageContainerName
  }
}

// Backing storage for Azure functions processor
module storage './core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
    }
    containers: [{name: deploymentStorageContainerName}]
  }
}

//Storage Blob Data Owner role, Storage Blob Data Contributor role, Storage Table Data Contributor role
// Allow access from API to storage account using a managed identity and Storage Blob Data Contributor and Data Owner role
var roleIds = ['b7e6dc6d-f1e8-4753-8033-0f276bb0955b', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3']
module storageBlobDataOwnerRoleDefinitionApi 'app/storage-Access.bicep' = [for roleId in roleIds: {
  name: 'blobDataOwner${roleId}'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    roleId: roleId
    principalIds: principalIds
  }
}]

module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
    }
  }
}

// Service Bus
module serviceBus 'core/message/servicebus.bicep' = {
  name: 'serviceBus'
  scope: rg
  params: {
    location: location
    tags: tags
    serviceBusNamespaceName: !empty(serviceBusNamespaceName) ? serviceBusNamespaceName : '${abbrs.serviceBusNamespaces}${resourceToken}'
    serviceBusQueueName : !empty(serviceBusQueueName) ? serviceBusQueueName : '${abbrs.serviceBusNamespacesQueues}${resourceToken}'
  }
}

var ServiceBusRoleDefinitionIds  = ['090c5cfd-751d-490a-894a-3ce6f1109419', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'] //Azure Service Bus Data Owner and Data Receiver roles
// Allow access from processor to Service Bus using a managed identity and Azure Service Bus Data Owner and Data Receiver roles
module ServiceBusDataOwnerRoleAssignment 'app/servicebus-Access.bicep' = [for roleId in ServiceBusRoleDefinitionIds: {
  name: 'sbRoleAssignment${roleId}'
  scope: rg
  params: {
    serviceBusNamespaceName: serviceBus.outputs.serviceBusNamespace
    roleDefinitionId: roleId
    principalIds: principalIds
  }
}]

// Virtual Network & private endpoint
module serviceVirtualNetwork 'app/vnet.bicep' = {
  name: 'serviceVirtualNetwork'
  scope: rg
  params: {
    location: location
    tags: tags
    vNetName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
  }
}

module servicePrivateEndpoint 'app/servicebus-privateEndpoint.bicep' = {
  name: 'servicePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: serviceVirtualNetwork.outputs.sbSubnetName
    sbNamespaceId: serviceBus.outputs.namespaceId
  }
}

module storagePrivateEndpoint 'app/storage-PrivateEndpoint.bicep' = {
  name: 'storagePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: serviceVirtualNetwork.outputs.stSubnetName
    resourceName: storage.outputs.name
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
  }
}

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output SERVICE_PROCESSOR_NAME string = processor.outputs.SERVICE_PROCESSOR_NAME
output AZURE_FUNCTION_NAME string = processor.outputs.SERVICE_PROCESSOR_NAME
