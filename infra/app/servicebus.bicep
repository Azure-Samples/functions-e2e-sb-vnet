@description('The name of the Service Bus namespace')
param serviceBusNamespaceName string

@description('The name of the Service Bus queue')
param serviceBusQueueName string

@description('The location where resources will be deployed')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {}

@description('The SKU of the Service Bus namespace')
param sku object = {
  name: 'Premium'
}

@description('Whether to disable local authentication for the Service Bus namespace')
param disableLocalAuth bool = true

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  tags: tags
  sku: sku
  properties: {
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: disableLocalAuth
  }
}

resource serviceBusQueue  'Microsoft.ServiceBus/namespaces/queues@2022-01-01-preview' = {
  parent: serviceBusNamespace
  name: serviceBusQueueName
}

@description('The resource ID of the Service Bus namespace')
output namespaceId string = serviceBusNamespace.id

@description('The name of the Service Bus queue')
output serviceBusQueueName string = serviceBusQueue.name

@description('The fully qualified domain name of the Service Bus namespace')
output serviceBusNamespaceFQDN string = '${serviceBusNamespace.name}.servicebus.windows.net'

@description('The name of the Service Bus namespace')
output serviceBusNamespace string = serviceBusNamespace.name