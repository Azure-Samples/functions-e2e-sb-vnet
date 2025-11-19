#!/usr/bin/env pwsh
param()

# Get environment values
$output = azd env get-values

# Parse the output to get the resource names and the resource group
$lines = $output -split "`n"

foreach ($line in $lines) {
    if ($line -like "SERVICEBUS_CONNECTION__fullyQualifiedNamespace*") {
        $ServiceBusNamespace = ($line -split "=")[1].Trim('"') -replace ".servicebus.windows.net", ""
    }
    elseif ($line -like "RESOURCE_GROUP*") {
        $ResourceGroup = ($line -split "=")[1].Trim('"')
    }
}

# VNet is always enabled for this sample - always configure network rules
Write-Output "Adding the client IP to the network rule of the Service Bus service"

# Get the client IP
$ClientIP = Invoke-RestMethod -Uri 'https://api.ipify.org'

Write-Output "Adding client IP $ClientIP to Service Bus network rules"

# Add the client IP to the network rule and mark the public network access as enabled since the client IP is added to the network rule
az servicebus namespace network-rule-set create --resource-group $ResourceGroup --namespace-name $ServiceBusNamespace --default-action "Deny" --public-network-access "Enabled" --ip-rules "[{action:Allow,ip-address:$ClientIP}]" | Out-Null

Write-Output "Successfully updated Service Bus network rules"

Write-Output "Client IP configuration completed"