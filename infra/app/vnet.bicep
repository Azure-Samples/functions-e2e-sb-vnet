@description('Specifies the name of the virtual network.')
param vNetName string

@description('Specifies the location.')
param location string = resourceGroup().location

@description('Specifies the name of the subnet for the Service Bus private endpoint.')
param sbSubnetName string = 'sb'

@description('Specifies the name of the subnet for Function App virtual network integration.')
param appSubnetName string = 'app'

@description('Specifies the name of the subnet for the storage account.')
param stSubnetName string = 'st'

param tags object = {}

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.7.1' = {
  name: '${uniqueString(deployment().name, location)}-vnet'
  params: {
    name: vNetName
    location: location
    tags: tags
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    subnets: [
      {
        name: sbSubnetName
        addressPrefixes: [
          '10.0.1.0/24'
        ]
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
      {
        name: appSubnetName
        addressPrefixes: [
          '10.0.2.0/23'
        ]
        delegation: 'Microsoft.App/environments'
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
      {
        name: stSubnetName
        addressPrefixes: [
          '10.0.4.0/24'
        ]
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    ]
  }
}

output sbSubnetName string = virtualNetwork.outputs.subnetNames[0]
output sbSubnetID string = virtualNetwork.outputs.subnetResourceIds[0]
output appSubnetName string = virtualNetwork.outputs.subnetNames[1]
output appSubnetID string = virtualNetwork.outputs.subnetResourceIds[1]
output stSubnetName string = virtualNetwork.outputs.subnetNames[2]
output stSubnetID string = virtualNetwork.outputs.subnetResourceIds[2]
output resourceId string = virtualNetwork.outputs.resourceId
