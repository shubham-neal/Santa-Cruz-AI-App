#!/bin/bash
# Note: The script should be run as sudo


# Exit the script on any error
set -e

source functions.sh

while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --rg-ams)
            RESOURCE_GROUP_AMS="$2"
            shift # past argument
            shift # past value
            ;;
        --rg-device)
            RESOURCE_GROUP_DEVICE="$2"
            shift # past argument
            shift # past value
            ;;
		--help)
            PRINT_HELP="true"
            shift # past argument
            ;;
        *)    
            # unknown option
            echo "Unknown parameter passed: $1"
            printHelp
            exit 0
            ;;
    esac
done


if [ "$PRINT_HELP" == "true" ]; then
	printHelp
	exit 0
elif [ -z "$RESOURCE_GROUP_AMS" ]; then
	echo "$(error) required parameter RESOURCE_GROUP_AMS is missing from the command"
	printHelp
	exitWithError
elif [ -z "$RESOURCE_GROUP_DEVICE" ]; then
	RESOURCE_GROUP_DEVICE="$RESOURCE_GROUP_AMS"
fi

# Check if required packages are installed
checkPackageInstallation


# Run uname to get current device architecture
DEVICE_ARCHITECTURE="x86"
#Run command to get current device runtime
DEVICE_RUNTIME="CPU"

RANDOM_SUFFIX="$(echo "$RESOURCE_GROUP_AMS" | md5sum | cut -c1-4)"
RANDOM_NUMBER="${RANDOM:0:3}"

IOTHUB_NAME="azureeye"
IOTHUB_NAME=${IOTHUB_NAME}${RANDOM_SUFFIX}
DEVICE_NAME="azureeye"
USE_EXISTING_RESOURCES="true"
LOCATION="westus2"




# Check if already logged in using az ad signed-in-user 

IS_LOGGED_IN=$(az account show)

if [ -z "$IS_LOGGED_IN" ]; then
	echo "$(info) Attempting login"
	# Timeout Azure Login step if the user does not complete the login process in 3 minutes
	timeout --foreground 3m az login --output "none" || (echo "$(error) Interactive login timed out" && exitWithError)
	echo "$(info) Login successful"	
else
	echo "Using existing login"
fi


# Getting the details of subscriptions which user has access, in case when value is not provided in variable.template
if [ -z "$SUBSCRIPTION_ID" ]; then
    # Value is empty for SUBSCRIPTION_ID
    # Assign Default value to current subscription
    subscriptions=$(az account list)
    
    SUBSCRIPTION_ID=$(az account list --query "[0].id" -o tsv)
    
    if [ ${#subscriptions[*]} -gt 1 ]; then
        echo "[WARNING] User has access to more than one subscription, by default using first subscription: \"$SUBSCRIPTION_ID\""
    fi
fi

echo "$(info) Setting current subscription to \"$SUBSCRIPTION_ID\""
az account set --subscription "$SUBSCRIPTION_ID"
echo "$(info) Successfully set subscription to \"$SUBSCRIPTION_ID\""


if [ "$(az group exists --name "$RESOURCE_GROUP_DEVICE")" == false ]; then
    echo "$(info) Creating a new Resource Group: \"$RESOURCE_GROUP_DEVICE\""
    az group create --name "$RESOURCE_GROUP_DEVICE" --location "$LOCATION" --output "none"
    echo "$(info) Successfully created resource group"
else
    if [ "$USE_EXISTING_RESOURCES" == "true" ]; then
        echo "$(info) Using Existing Resource Group: \"$RESOURCE_GROUP_DEVICE\" for IoT Hub"
    else
        echo "$(error) Resource Group \"$RESOURCE_GROUP_DEVICE\" already exists"
        exitWithError
    fi
fi


printf "\n%60s\n" " " | tr ' ' '-'
echo "Configuring IoT Hub"
printf "%60s\n" " " | tr ' ' '-'

# We are checking if the IoTHub already exists by querying the list of IoT Hubs in current subscription.
# It will return a blank array if it does not exist. Create a new IoT Hub if it does not exist,
# if it already exists then check value for USE_EXISTING_RESOURCES. If it is set to yes, use existing IoT Hub.
EXISTING_IOTHUB=$(az iot hub list --query "[?name=='$IOTHUB_NAME'].{Name:name}" --output tsv)

if [ -z "$EXISTING_IOTHUB" ]; then
    echo "$(info) Creating a new IoT Hub \"$IOTHUB_NAME\""
    az iot hub create --name "$IOTHUB_NAME" --sku S1 --resource-group "$RESOURCE_GROUP_DEVICE" --output "none"
    echo "$(info) Created a new IoT hub \"$IOTHUB_NAME\""
else
    # Check if IoT Hub exists in current resource group. If it exist, we will use the existing IoT Hub.
    EXISTING_IOTHUB=$(az iot hub list --resource-group "$RESOURCE_GROUP_DEVICE" --query "[?name=='$IOTHUB_NAME'].{Name:name}" --output tsv)
    if [ "$USE_EXISTING_RESOURCES" == "true" ] && [ -n "$EXISTING_IOTHUB" ]; then
        echo "$(info) Using existing IoT Hub \"$IOTHUB_NAME\""
    else
        if [ "$USE_EXISTING_RESOURCES" == "true" ]; then
            echo "$(info) \"$IOTHUB_NAME\" already exists in current subscription but it does not exist in resource group \"$RESOURCE_GROUP_DEVICE\""
        else
            echo "$(info) \"$IOTHUB_NAME\" already exists"
        fi
        echo "$(info) Appending a random number \"$RANDOM_NUMBER\" to \"$IOTHUB_NAME\""
        IOTHUB_NAME=${IOTHUB_NAME}${RANDOM_NUMBER}
        # Writing the updated value back to variables file

        echo "$(info) Creating a new IoT Hub \"$IOTHUB_NAME\""
        az iot hub create --name "$IOTHUB_NAME" --sku S1 --resource-group "$RESOURCE_GROUP_DEVICE" --output "none"
        echo "$(info) Created a new IoT hub \"$IOTHUB_NAME\""
    fi
fi

# This step creates a new edge device in the IoT Hub account or will use an existing edge device
# if the USE_EXISTING_RESOURCES configuration variable is set to true.
printf "\n%60s\n" " " | tr ' ' '-'
echo "Configuring Edge Device in IoT Hub"
printf "%60s\n" " " | tr ' ' '-'

# Check if a Edge Device with given name already exists in IoT Hub. Create a new one if it doesn't exist already.
EXISTING_IOTHUB_DEVICE=$(az iot hub device-identity list --hub-name "$IOTHUB_NAME" --query "[?deviceId=='$DEVICE_NAME'].deviceId" -o tsv)
if [ -z "$EXISTING_IOTHUB_DEVICE" ]; then
    echo "$(info) Creating an Edge device \"$DEVICE_NAME\" in IoT Hub \"$IOTHUB_NAME\""
    az iot hub device-identity create --hub-name "$IOTHUB_NAME" --device-id "$DEVICE_NAME" --edge-enabled --output "none"
    echo "$(info) Created \"$DEVICE_NAME\" device in IoT Hub \"$IOTHUB_NAME\""
else
    echo "$(info) Using existing IoT Hub Edge Device \"$DEVICE_NAME\""
fi

# The following steps retrieves the connection string for the edge device an uses it to onboard
# the device using sshpass. This step may fail if the edge device's network firewall
# does not allow ssh access. Please make sure the edge device is on the local area
# network and is accepting ssh requests.
echo "$(info) Retrieving connection string for device \"$DEVICE_NAME\" from Iot Hub \"$IOTHUB_NAME\" and updating the IoT Edge service in edge device with this connection string"
EDGE_DEVICE_CONNECTION_STRING=$(az iot hub device-identity connection-string show --device-id "$DEVICE_NAME" --hub-name "$IOTHUB_NAME" --query "connectionString" -o tsv)

echo "$(info) Updating Config.yaml on edge device with the connection string from IoT Hub"
CONFIG_FILE_PATH="/etc/iotedge/config.yaml"
# Replace placeholder connection string with actual value for Edge device
# Using sshpass and ssh to update the value on Edge device
Command=$(echo "sudo sed -i -e '/device_connection_string:/ s#\"[^\"][^\"]*\"#\"$EDGE_DEVICE_CONNECTION_STRING\"#' $CONFIG_FILE_PATH")
$Command
echo "$(info) Config.yaml update is complete"

echo "$(info) Restarting IoT Edge service"
# Restart the service on Edge device
sudo systemctl restart iotedge
echo "$(info) IoT Edge service restart is complete"



AMS_RG_SCOPE="/subscription/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_AMS}"

echo "Creating service principal for Azure Media Service"
AMS_SP=$(az ad sp create-for-rbac --name "AMS-SP-$RESOURCE_GROUP_AMS" --role "contributor" --scope "${AMS_RG_SCOPE}")
AMS_SP_ID=$(echo "$AMS_SP" | jq -r '.appId')
AMS_SP_Password=$(echo "$AMS_SP" | jq -r '.password')

# Download ARM template and run from Az CLI

ARM_TEMPLATE_URL="https://unifiededgescenariostest.blob.core.windows.net/test/azuredeploylva.json"

echo "Downloading ARM template"
wget -O azuredeploylva.json "$ARM_TEMPLATE_URL"

echo "Running ARM template"

az deployment sub create --location "$LOCATION" --template-file "azuredeploylva.json" --no-prompt \
	--parameters resourceGroupDevice=$RESOURCE_GROUP_DEVICE resourceGroupAMS=$RESOURCE_GROUP_AMS existingIotHubName=$IOTHUB_NAME existingDeviceName=$DEVICE_NAME servicePrincipalId=$AMS_SP_ID servicePrincipalSecret=$AMS_SP_Password

