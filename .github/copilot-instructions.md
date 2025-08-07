# Azure Functions Service Bus + VNet Integration Sample

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

This sample demonstrates a Flex Consumption Azure Functions app that securely connects to Service Bus using virtual network integration. The function processes messages from a Service Bus queue secured behind a private endpoint.

## Working Effectively

### Bootstrap and Environment Setup
- **Python 3.12+** (required for Azure Functions Python v2 programming model):
  - Check version: `python3 --version`
  - This sample requires Python 3.12+
- **Azure CLI** (always available in GitHub Codespaces/Actions):
  - Check version: `az --version` (requires v2.x)
  - Bicep CLI included: `az bicep version`
- **Azure Dev CLI (azd)** - REQUIRED for deployment:
  - Installation may fail in restricted environments
  - In restricted environments: `curl -fsSL https://aka.ms/install-azd.sh | bash` may fail due to network limitations
  - Alternative: Use manual installation or Azure Cloud Shell
- **Azure Functions Core Tools v4** - OPTIONAL for local testing:
  - Installation may fail in restricted environments due to network limitations
  - `npm install -g azure-functions-core-tools@4` often fails
  - Not required for main deployment workflow which uses `azd up`

### Python Environment and Dependencies
- **Create Python virtual environment** (takes ~10 seconds):
  ```bash
  cd src
  python3 -m venv .venv
  source .venv/bin/activate  # Linux/Mac
  # .venv\Scripts\activate   # Windows
  ```
- **Install dependencies** (takes 30-60 seconds, may fail in restricted networks):
  ```bash
  pip install --upgrade pip
  pip install -r requirements.txt
  ```
- **Install development tools** (takes 30-60 seconds, may fail in restricted networks):
  ```bash
  pip install flake8 black
  ```
- **NOTE**: In restricted environments (GitHub Codespaces/CI), pip install may timeout or fail due to network limitations. The core azure-functions package installation should be prioritized.

### Code Validation (ALWAYS run before changes)
- Validate Python syntax (takes ~0.03 seconds):
  ```bash
  cd src && source .venv/bin/activate
  python -m py_compile function_app.py
  ```
- Run linting (takes ~0.1 seconds):
  ```bash
  cd src && source .venv/bin/activate
  flake8 function_app.py
  ```
- Format code (takes ~0.1 seconds):
  ```bash
  cd src && source .venv/bin/activate
  black function_app.py
  ```

### Infrastructure Validation
- Validate Bicep templates (takes ~5 seconds):
  ```bash
  az bicep build --file infra/main.bicep --outfile /tmp/main.json
  ```
- Check for Bicep compilation warnings - the sample has known warnings that can be ignored

### Deployment (CRITICAL TIMING)
- **NEVER CANCEL**: Complete deployment takes 15-25 minutes. NEVER CANCEL. Set timeout to 35+ minutes.
- Authenticate with Azure CLI and Azure Dev CLI:
  ```bash
  az login
  azd auth login
  ```
- Deploy infrastructure and application:
  ```bash
  azd up
  ```
  - **Takes 15-25 minutes to complete**
  - Creates resource group, VNet, Service Bus, Functions app, storage, and all networking
  - Will prompt for environment name and region
  - Will prompt for VM password (for testing VM in the VNet)

### Testing and Validation Scenarios
After deployment, ALWAYS test these scenarios:

1. **Verify Infrastructure**:
   - Check Azure portal resource group created by azd
   - Verify Service Bus namespace has public access disabled
   - Verify Service Bus has private endpoint configured
   - Verify Function App has VNet integration configured

2. **Test Message Processing**:
   - Navigate to Service Bus in Azure portal
   - Add your client IP to Service Bus firewall (Networking > Firewalls and virtual networks)
   - Use Service Bus Explorer to send test messages to the queue
   - Monitor Application Insights Live Metrics to see scaling and message processing
   - Each message takes 30 seconds to process (by design - see `time.sleep(30)` in function_app.py)

3. **Validate Scaling**:
   - Send 10-50 messages to Service Bus queue
   - Watch Application Insights Live Metrics
   - Verify function app scales to multiple instances (up to 100 max)
   - Due to `maxConcurrentCalls: 1` setting in host.json, each instance processes one message at a time

## Repository Structure

### Key Files
- `src/function_app.py` - Main Azure Function using v2 programming model
- `src/requirements.txt` - Python dependencies (azure-functions only)
- `src/host.json` - Function app configuration with Service Bus concurrency settings
- `azure.yaml` - Azure Dev CLI project definition
- `infra/main.bicep` - Main infrastructure template (creates 15+ Azure resources)
- `infra/app/processor.bicep` - Function app infrastructure
- `infra/core/` - Reusable infrastructure modules

### Infrastructure Components (15 Bicep files)
- Flex Consumption Function App with VNet integration
- Service Bus namespace with private endpoint
- Virtual Network with subnets for app and private endpoints
- Storage account with private endpoint
- Application Insights for monitoring
- User-assigned managed identity for secure connections
- RBAC role assignments for storage and Service Bus access

## Common Issues and Solutions

### Build/Deployment Issues
- If `azd up` fails, check Azure CLI authentication: `az account show`
- If Function deployment fails, verify storage account access via managed identity
- Service Bus connection uses managed identity, not connection strings

### Development Issues
- **Functions Core Tools may not install easily** in all environments - focus on Azure Dev CLI workflow
- **Local testing requires Service Bus connection string** or emulator setup
- **The sample is designed for cloud deployment**, not local development
- **In restricted environments**: Skip local tools installation, focus on code validation and azd deployment

### Environment-Specific Workflows

#### Full Development Environment (Local/Cloud Shell)
```bash
# Full setup with all tools
python3 -m venv src/.venv && source src/.venv/bin/activate
pip install -r src/requirements.txt && pip install flake8 black
az bicep build --file infra/main.bicep --outfile /tmp/validation.json
azd auth login && azd up
```

#### Restricted Environment (GitHub Codespaces/CI)
```bash
# Minimal setup focusing on validation and deployment
python3 -m venv src/.venv && source src/.venv/bin/activate
pip install azure-functions  # May timeout - retry if needed
python -m py_compile src/function_app.py
az bicep build --file infra/main.bicep --outfile /tmp/validation.json
# azd up (requires azd installation success)
```

### Testing Issues
- Service Bus Explorer requires firewall configuration to send messages
- Function scaling may take 2-3 minutes to become visible in Live Metrics
- Messages process slowly (30 seconds each) by design to demonstrate scaling

## Timing Expectations and Critical Warnings

### Command Timing (measured on standard development environment)
- Python environment setup: 10 seconds
- Dependency installation: 30-60 seconds (may timeout in restricted networks)
- Code validation (linting, compilation): < 1 second each
- Infrastructure validation (Bicep compilation): ~5 seconds
- **Full deployment (`azd up`): 15-25 minutes - NEVER CANCEL - Set timeout to 35+ minutes**
- Message processing: 30 seconds per message (intentional delay in function_app.py)
- Resource cleanup (`azd down`): 2-5 minutes

### CRITICAL: Network and Environment Limitations
- **Restricted environments** (GitHub Codespaces, CI runners) may have network limitations
- **Azure Dev CLI and Functions Core Tools** installation may fail due to network restrictions
- **pip install** may timeout - retry or use cached packages if available
- **Focus on core workflow**: Bicep validation and azd deployment rather than local development tools

## VS Code Integration

The repository includes VS Code configuration in `src/.vscode/`:
- `launch.json` - Debug configuration for Azure Functions
- `tasks.json` - Build tasks for pip install and func host start
- `settings.json` - Azure Functions extension settings

## CRITICAL REMINDERS

- **NEVER CANCEL BUILDS OR DEPLOYMENTS** - They take 15-25 minutes and cancellation will leave resources in inconsistent state
- **ALWAYS validate code syntax and linting** before deployment
- **ALWAYS test message processing scenarios** after deployment
- **Set timeout values of 35+ minutes** for all deployment operations
- **This is an infrastructure sample** - focus on deployment and Azure configuration rather than complex code changes

## Quick Reference Commands

### Essential Validation (Always Run)
```bash
# Syntax check (required)
cd src && python -m py_compile function_app.py

# Infrastructure validation (required)
az bicep build --file infra/main.bicep --outfile /tmp/validation.json

# Authentication check
az account show
```

### Deployment Workflow
```bash
# Authenticate (required once)
az login
azd auth login

# Deploy (15-25 minutes - NEVER CANCEL)
azd up

# Clean up when done
azd down
```

### Development Commands (if tools available)
```bash
# Setup environment
cd src && python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Code quality (optional)
flake8 function_app.py
black function_app.py
```