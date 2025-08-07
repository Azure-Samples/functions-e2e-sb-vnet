@description('The name of the App Service Plan')
param name string

@description('The location where the App Service Plan will be deployed')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('The SKU configuration for the App Service Plan')
param sku object = {
  name: 'FC1'
  tier: 'FlexConsumption'
}

@description('Whether the App Service Plan is reserved (Linux)')
param reserved bool = true

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: name
  location: location
  tags: tags
  sku: sku
  properties: {
    reserved: reserved
  }
}

@description('The resource ID of the App Service Plan')
output resourceId string = appServicePlan.id

@description('The name of the App Service Plan')
output name string = appServicePlan.name