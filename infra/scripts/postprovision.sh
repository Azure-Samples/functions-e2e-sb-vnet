#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""

# Get the outputs from the deployment
outputs=$(azd env get-values --output json)

# Extract values using jq (more robust) or grep/sed fallback
if command -v jq &> /dev/null; then
    serviceBusNamespace=$(echo "$outputs" | jq -r '.SERVICEBUS_CONNECTION__fullyQualifiedNamespace')
    serviceBusQueueName=$(echo "$outputs" | jq -r '.SERVICEBUS_QUEUE_NAME')
    functionAppName=$(echo "$outputs" | jq -r '.SERVICE_API_NAME')
else
    # Fallback using grep and sed if jq is not available
    serviceBusNamespace=$(echo "$outputs" | grep '"SERVICEBUS_CONNECTION__fullyQualifiedNamespace"' | sed 's/.*"SERVICEBUS_CONNECTION__fullyQualifiedNamespace"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    serviceBusQueueName=$(echo "$outputs" | grep '"SERVICEBUS_QUEUE_NAME"' | sed 's/.*"SERVICEBUS_QUEUE_NAME"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    functionAppName=$(echo "$outputs" | grep '"SERVICE_API_NAME"' | sed 's/.*"SERVICE_API_NAME"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
fi

echo -e "${YELLOW}Service Bus Processing System deployed successfully!${NC}"
echo ""
echo -e "${CYAN}System components:${NC}"
echo -e "${WHITE}  📨 Service Bus Queue Processor Function: Processes messages from Service Bus queue${NC}"
echo -e "${WHITE}  🔄 Service Bus Queue: service-bus-queue${NC}"
echo -e "${WHITE}  🌐 Service Bus Namespace: $serviceBusNamespace${NC}"
echo ""
echo -e "${GREEN}🚀 Function is now running in Azure!${NC}"
echo ""
echo -e "${YELLOW}To monitor the system:${NC}"
echo -e "${WHITE}  1. View Function App logs in Azure Portal${NC}"
echo -e "${WHITE}  2. Check Application Insights for real-time metrics${NC}"
echo -e "${WHITE}  3. Monitor Service Bus message flow${NC}"
echo ""
echo -e "${CYAN}Expected behavior:${NC}"
echo -e "${WHITE}  • Function processes messages from Service Bus queue using managed identity${NC}"
echo -e "${WHITE}  • Messages are processed securely without connection strings${NC}"
echo -e "${WHITE}  • View processing logs in Azure Portal${NC}"
echo ""
echo -e "${YELLOW}Function App Name: $functionAppName${NC}"

set -e

echo -e "${YELLOW}Creating/updating local.settings.json...${NC}"

cat <<EOF > ./src/local.settings.json
{
    "IsEncrypted": "false",
    "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "python",
        "ServiceBusConnection__fullyQualifiedNamespace": "$serviceBusNamespace",
        "ServiceBusQueueName": "$serviceBusQueueName"
    }
}
EOF

echo -e "${GREEN}✅ local.settings.json has been created/updated successfully!${NC}"
echo ""
echo -e "${CYAN}Local development setup complete!${NC}"
echo -e "${WHITE}To run locally:${NC}"
echo -e "${WHITE}  1. Start Azurite: azurite --location ./data --debug ./debug.log${NC}"
echo -e "${WHITE}  2. Navigate to src/: cd src${NC}"
echo -e "${WHITE}  3. Start functions: func start${NC}"
echo ""
echo -e "${YELLOW}Note: Local testing requires your user identity to have Service Bus Data Receiver/Sender permissions${NC}"