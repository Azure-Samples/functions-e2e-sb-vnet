@description('The name of the storage account')
param name string

@description('The location where the storage account will be deployed')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('Whether to allow blob public access')
param allowBlobPublicAccess bool = false

@description('Whether to allow shared key access (local authentication)')
param allowSharedKeyAccess bool = false

@description('DNS endpoint type')
param dnsEndpointType string = 'Standard'

@description('Public network access setting')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Disabled'

@description('Network ACLs configuration')
param networkAcls object = {
  defaultAction: 'Deny'
  bypass: 'None'
}

@description('Minimum TLS version')
param minimumTlsVersion string = 'TLS1_2'

@description('Blob services configuration including containers')
param blobServices object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: allowBlobPublicAccess
    allowSharedKeyAccess: allowSharedKeyAccess
    dnsEndpointType: dnsEndpointType
    publicNetworkAccess: publicNetworkAccess
    networkAcls: networkAcls
    minimumTlsVersion: minimumTlsVersion
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = if (contains(blobServices, 'containers')) {
  parent: storageAccount
  name: 'default'
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for container in (contains(blobServices, 'containers') ? blobServices.containers : []): {
  parent: blobService
  name: container.name
  properties: {
    publicAccess: 'None'
  }
}]

@description('The resource ID of the storage account')
output resourceId string = storageAccount.id

@description('The name of the storage account')
output name string = storageAccount.name

@description('The primary endpoints of the storage account')
output primaryEndpoints object = storageAccount.properties.primaryEndpoints