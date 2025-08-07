@description('The name of the user assigned identity')
param name string

@description('The location where the identity will be deployed')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

@description('The resource ID of the user assigned identity')
output resourceId string = userAssignedIdentity.id

@description('The principal ID of the user assigned identity')
output principalId string = userAssignedIdentity.properties.principalId

@description('The client ID of the user assigned identity')
output clientId string = userAssignedIdentity.properties.clientId

@description('The name of the user assigned identity')
output name string = userAssignedIdentity.name