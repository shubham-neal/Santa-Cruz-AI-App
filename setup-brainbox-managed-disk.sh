#!/usr/bin/env bash

# This script creates an managed disk from a VHD file in blob storage using a AzCopy.
# It performs the following steps:
#	1. Login to Azure
#	2. Create an empty managed disk in ForUpload state
#	3. Generate a SAS Token for the managed disk
#	4. Copy the vhd blob file from a storage container to managed disk using AzCopy
#	5. Remove the SAS Token. This will changed the state from ForUpload to Unattached

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
DISK_NAME="brainbox"
STORAGE_TYPE="Premium_LRS"

# VHD_URI is the direct link for VHD file in storage account. The VHD file must be in the current subscription
VHD_URI="https://georgembbox.blob.core.windows.net/brainbox/brainbox-dev-1.0.MM5.20200603.2120.vhd?sp=r&st=2020-07-15T14:31:52Z&se=2099-12-30T22:31:52Z&spr=https&sv=2019-10-10&sr=b&sig=tS%2BihEfXWPbtDRfsHIs28%2Fi6eeDGp5deUuoQmv%2FPpSg%3D"

# Stop execution on any error from azure cli
set -e

# Helper function
info() {
    echo "$(date +"%Y-%m-%d %T") [INFO]"
}

# Define helper function for logging. This will change the Error text color to red
error() {
    echo "$(tput setaf 1)$(date +"%Y-%m-%d %T") [ERROR]"
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

# Check if disk already exists
EXISTING_DISK=$(az disk list --resource-group "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" --query "[?name=='$DISK_NAME'].{Name:name}" --output tsv)
if [ -z "$EXISTING_DISK" ]; then
    echo "$(info) Creating empty managed disk \"$DISK_NAME\""
    # The upload size bytes must be same as size of the VHD file
    az disk create -n "$DISK_NAME" -g "$RESOURCE_GROUP" -l "$LOCATION" --for-upload --upload-size-bytes 68719477248 --sku "$STORAGE_TYPE" --os-type "Linux" --hyper-v-generation "V2" --output "none"
    echo "$(info) Created empty managed disk \"$DISK_NAME\""
else
    echo "$(error) Managed Disk \"$DISK_NAME\" already exists in resource group \"$RESOURCE_GROUP\""
    exit 1
fi

echo "$(info) Fetching the SAS Token"
SAS_URI=$(az disk grant-access -n "$DISK_NAME" -g "$RESOURCE_GROUP" --access-level Write --duration-in-seconds 86400)
TOKEN=$(echo "$SAS_URI" | jq -r '.accessSas')
echo "$(info) Retrieved the SAS Token"

echo "$(info) Copying vhd file from source to destination"
sudo azcopy copy "$VHD_URI" "$TOKEN" --blob-type PageBlob
echo "$(info) Copy is complete"

echo "$(info) Revoking SAS"
az disk revoke-access -n "$DISK_NAME" -g "$RESOURCE_GROUP" --output "none"
echo "$(info) SAS REVOKED"

echo "$(info) Managed disk setup is complete"
