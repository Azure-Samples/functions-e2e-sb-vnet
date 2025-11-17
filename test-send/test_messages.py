#!/usr/bin/env python3
"""
Simple test script to send messages to Service Bus for testing the Azure Functions app.

Usage:
    python test_messages.py [number_of_messages]

Requirements:
    pip install azure-servicebus azure-identity

The script will use your Azure CLI credentials (run 'az login' first).
It automatically finds and reads the Service Bus configuration from src/local.settings.json,
regardless of which directory you run the script from.
"""

import json
import sys
import os
from azure.servicebus import ServiceBusClient, ServiceBusMessage
from azure.identity import DefaultAzureCredential
from datetime import datetime


def load_local_settings():
    """Load Service Bus connection details from local.settings.json"""
    # Get the script's directory and navigate to src/local.settings.json
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)  # Go up one level from test-send/
    settings_path = os.path.join(project_root, "src", "local.settings.json")
    
    if not os.path.exists(settings_path):
        raise FileNotFoundError(
            f"Could not find {settings_path}. "
            "Make sure you've run 'azd provision' to deploy the infrastructure first."
        )
    
    with open(settings_path, 'r') as f:
        settings = json.load(f)
    
    values = settings.get('Values', {})
    
    # Try multiple possible naming conventions
    namespace = (
        values.get('SERVICEBUS_CONNECTION__fullyQualifiedNamespace') or
        values.get('ServiceBusConnection__fullyQualifiedNamespace')
    )
    
    if not namespace:
        raise ValueError(
            "Service Bus namespace not found in local.settings.json. "
            "Looking for 'SERVICEBUS_CONNECTION__fullyQualifiedNamespace' or 'ServiceBusConnection__fullyQualifiedNamespace'"
        )
    
    # Also get the queue name if available
    queue_name = (
        values.get('SERVICEBUS_QUEUE_NAME') or
        values.get('ServiceBusQueueName')
    )
    
    return namespace, queue_name


def get_queue_name_from_env():
    """Try to get queue name from environment or use default pattern"""
    # Try to read from .env file if it exists
    env_path = ".env"
    if os.path.exists(env_path):
        with open(env_path, 'r') as f:
            for line in f:
                if line.startswith('SERVICEBUS_QUEUE_NAME='):
                    return line.split('=', 1)[1].strip().strip('"\'')
    
    # If not found, we'll need to get it from Azure CLI
    try:
        import subprocess
        result = subprocess.run(
            ['azd', 'env', 'get-values'],
            capture_output=True,
            text=True,
            check=True
        )
        for line in result.stdout.split('\n'):
            if line.startswith('SERVICEBUS_QUEUE_NAME='):
                return line.split('=', 1)[1].strip().strip('"\'')
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    
    # Default fallback - user will need to provide this
    print("⚠️  Could not automatically detect queue name.")
    queue_name = input("Enter your Service Bus queue name: ").strip()
    return queue_name


def send_messages(namespace: str, queue_name: str, num_messages: int = 5):
    """Send test messages to Service Bus"""
    print(f"🔐 Authenticating with Azure...")
    credential = DefaultAzureCredential()
    
    print(f"📡 Connecting to Service Bus: {namespace}")
    print(f"📤 Sending {num_messages} messages to queue: {queue_name}")
    
    with ServiceBusClient(f"https://{namespace}", credential) as client:
        sender = client.get_queue_sender(queue_name)
        
        # Create messages with timestamps and sequential numbering
        messages = []
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        for i in range(1, num_messages + 1):
            message_body = f"Test message {i}/{num_messages} - sent at {timestamp}"
            messages.append(ServiceBusMessage(message_body))
        
        with sender:
            sender.send_messages(messages)
        
        print(f"✅ Successfully sent {num_messages} messages!")
        print(f"🔍 Check your function logs to see them being processed")
        print(f"⏱️  Each message takes ~30 seconds to process")


def main():
    """Main entry point"""
    # Parse command line arguments
    num_messages = 5
    if len(sys.argv) > 1:
        try:
            num_messages = int(sys.argv[1])
            if num_messages <= 0:
                raise ValueError()
        except ValueError:
            print("❌ Please provide a positive integer for number of messages")
            print("Usage: python test_messages.py [number_of_messages]")
            sys.exit(1)
    
    try:
        print("🚀 Service Bus Message Sender")
        print("=" * 40)
        
        # Load configuration
        namespace, settings_queue_name = load_local_settings()
        
        # Use queue name from settings if available, otherwise try environment
        queue_name = settings_queue_name if settings_queue_name else get_queue_name_from_env()
        
        # Send messages
        send_messages(namespace, queue_name, num_messages)
        
    except FileNotFoundError as e:
        print(f"❌ Configuration Error: {e}")
        sys.exit(1)
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        print("\nTroubleshooting tips:")
        print("1. Make sure you're logged in to Azure CLI: az login")
        print("2. Verify you have access to the Service Bus namespace")
        print("3. Check that the queue name is correct")
        print("4. Install required packages: pip install azure-servicebus azure-identity")
        sys.exit(1)


if __name__ == "__main__":
    main()