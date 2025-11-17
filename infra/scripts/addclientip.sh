#!/bin/bash
set -e

# Get environment values
output=$(azd env get-values)

# Parse the output to get the resource names and the resource group
while IFS= read -r line; do
    if [[ $line == SERVICEBUS_CONNECTION__fullyQualifiedNamespace* ]]; then
        ServiceBusNamespace=$(echo "$line" | cut -d '=' -f 2 | tr -d '"' | sed 's/.servicebus.windows.net//')
    elif [[ $line == RESOURCE_GROUP* ]]; then
        ResourceGroup=$(echo "$line" | cut -d '=' -f 2 | tr -d '"')
    fi
done <<< "$output"

# VNet is always enabled for this sample - always configure network rules
echo "Adding the client IP to the network rule of the Service Bus service"

# Get the client IP
ClientIP=$(curl -s https://api.ipify.org)

echo "Adding client IP $ClientIP to Service Bus network rules"
    
# Add the client IP to the network rule and mark the public network access as enabled since the client IP is added to the network rule
az servicebus namespace network-rule-set create --resource-group "$ResourceGroup" --namespace-name "$ServiceBusNamespace" --default-action "Deny" --public-network-access "Enabled" --ip-rules "[{action:Allow,ip-address:$ClientIP}]" > /dev/null
    
echo "Successfully updated Service Bus network rules"

echo "Client IP configuration completed"