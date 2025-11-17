Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host ""

# Get the outputs from the deployment
$outputs = azd env get-values --output json | ConvertFrom-Json
$ServiceBusNamespace = $outputs.SERVICEBUS_CONNECTION__fullyQualifiedNamespace

Write-Host "Service Bus Processing System deployed successfully!" -ForegroundColor Yellow
Write-Host ""
Write-Host "System components:" -ForegroundColor Cyan
Write-Host "  - Service Bus Queue Processor Function: Processes messages from Service Bus queue" -ForegroundColor White
Write-Host "  - Service Bus Queue: service-bus-queue" -ForegroundColor White
Write-Host "  - Service Bus Namespace: $ServiceBusNamespace" -ForegroundColor White
Write-Host ""
Write-Host "Function is now running in Azure!" -ForegroundColor Green
Write-Host ""
Write-Host "To monitor the system:" -ForegroundColor Yellow
Write-Host "  1. View Function App logs in Azure Portal" -ForegroundColor White
Write-Host "  2. Check Application Insights for real-time metrics" -ForegroundColor White
Write-Host "  3. Monitor Service Bus message flow" -ForegroundColor White
Write-Host ""
Write-Host "Expected behavior:" -ForegroundColor Cyan
Write-Host "  - Function processes messages from Service Bus queue using managed identity" -ForegroundColor White
Write-Host "  - Messages are processed securely without connection strings" -ForegroundColor White
Write-Host "  - View processing logs in Azure Portal" -ForegroundColor White
Write-Host ""
Write-Host "Function App Name: $($outputs.SERVICE_API_NAME)" -ForegroundColor Yellow

$ErrorActionPreference = "Stop"

Write-Host "Creating/updating local.settings.json..." -ForegroundColor Yellow

@{
    "IsEncrypted" = "false";
    "Values" = @{
        "AzureWebJobsStorage" = "UseDevelopmentStorage=true";
        "FUNCTIONS_WORKER_RUNTIME" = "python";
        "ServiceBusConnection__fullyQualifiedNamespace" = "$ServiceBusNamespace";
        "ServiceBusQueueName" = "$($outputs.SERVICEBUS_QUEUE_NAME)";
    }
} | ConvertTo-Json | Out-File -FilePath ".\src\local.settings.json" -Encoding ascii -Force

Write-Host "local.settings.json has been created/updated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Local development setup complete!" -ForegroundColor Cyan
Write-Host "To run locally:" -ForegroundColor White
Write-Host "  1. Start Azurite: azurite --location ./data --debug ./debug.log" -ForegroundColor White
Write-Host "  2. Navigate to src/: cd src" -ForegroundColor White
Write-Host "  3. Start functions: func start" -ForegroundColor White
Write-Host ""
Write-Host "Note: Local testing requires your user identity to have Service Bus Data Receiver/Sender permissions" -ForegroundColor Yellow