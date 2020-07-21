#!/usr/bin/env bash

# This script creates a Azure VM using a managed disk
# It performs the following steps:
#	1. Login to Azure
#	2. Create a VM from managed disk

# Name of the brainbox VM on Azure
VM_NAME="brainbox"
# Name of the managed disk
DISK_NAME="brainbox"

# Set it to true to use interactive login. If it is not set to true, service principal will be used for login.
USE_INTERACTIVE_LOGIN_FOR_AZURE="false"
TENANT_ID="72f988bf-86f1-41af-91ab-2d7cd011db47"
SUBSCRIPTION_ID="7c9469c0-29ac-424a-85ab-d01f2cea1c38"
# SP_APP_ID is the client id of the service principal. Service Principal should have access to create resources in given resource group
SP_APP_ID="48baeb10-1ccb-4457-9074-e3b52d4c8ca6"
# SP_APP_PWD is the client secret of the service principal.
SP_APP_PWD="Aht48-ILrE0n2HcSm62.PGk4C-J~_nTWI_"
RESOURCE_GROUP="rg-brainbox"
LOCATION="West US 2"
VM_SIZE="Standard_DS1_v2"

# Whether to create a rule in NSG for SSH or RDP.
# The following are the allowed values:
# 	NONE: Do not create any inbound security rule in NSG for RDP or SSH ports. (Recommended)
# 	SSH: Create an inbound security rule in NSG with priority 1000 for SSH port (22)
#	RDP: Create an inbound security rule in NSG with priority 1000 for RDP port (3389)
NSG_RULE="NONE"

# Stop execution on any error from azure cli
set -e

# Helper function
info() {
    echo "$(date +"%Y-%m-%d %T") [INFO]"
}

if [ "$USE_INTERACTIVE_LOGIN_FOR_AZURE" == "true" ]; then
    echo "$(info) Attempting login"
    az login --tenant "$TENANT_ID" --output "none"
    echo "$(info) Login successful"
else
    echo "$(info) Attempting login with Service Principal account"
    # Using service principal as it will not require user interaction
    az login --service-principal --username "$SP_APP_ID" --password "$SP_APP_PWD" --tenant "$TENANT_ID" --output "none"
    echo "$(info) Login successful"
fi

echo "$(info) Setting current subscription to \"$SUBSCRIPTION_ID\""
az account set --subscription "$SUBSCRIPTION_ID"
echo "$(info) Successfully set subscription to \"$SUBSCRIPTION_ID\""

echo "$(info) Creating virtual machine \"$VM_NAME\""
az vm create --name "$VM_NAME" --resource-group "$RESOURCE_GROUP" --attach-os-disk "$DISK_NAME" --os-type "linux" --location "$LOCATION" --nsg-rule "$NSG_RULE" --size "$VM_SIZE" --output "none"
echo "$(info) Created virtual machine \"$VM_NAME\""
