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
MEDIA_SERVICE_NAME="livevideoanalysis"
MEDIA_SERVICE_NAME=${MEDIA_SERVICE_NAME}${RANDOM_SUFFIX}
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

# Download ARM template and run from Az CLI

ARM_TEMPLATE_URL="https://unifiededgescenariostest.blob.core.windows.net/test/resources-deploy-bbox.json"

echo "Downloading ARM template"
wget -O resources-deploy-bbox.json "$ARM_TEMPLATE_URL"

echo "Running ARM template"

az deployment sub create --location "$LOCATION" --template-file "resources-deploy-bbox.json" --no-prompt \
	--parameters resourceGroupDevice=$RESOURCE_GROUP_DEVICE resourceGroupAMS=$RESOURCE_GROUP_AMS iotHubName=$IOTHUB_NAME mediaServiceName=$MEDIA_SERVICE_NAME
    
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
SCRIPT_PATH="/etc/iotedge/configedge.sh"
# Replace placeholder connection string with actual value for Edge device using the 'configedge.sh' script

source "$SCRIPT_PATH" "$EDGE_DEVICE_CONNECTION_STRING"

echo "$(info) Updated Config.yaml"

# creating the AMS account creates a service principal, so we'll just reset it to get the credentials
# echo "setting up service principal..."
# SPN="$MEDIA_SERVICE_NAME-access-sp" # this is the default naming convention used by `az ams account sp`

# if test -z "$(az ad sp list --display-name $SPN --query="[].displayName" -o tsv)"; then
    # AMS_CONNECTION=$(az ams account sp create -o yaml --resource-group $RESOURCE_GROUP_AMS --account-name $MEDIA_SERVICE_NAME)
# else
    # AMS_CONNECTION=$(az ams account sp reset-credentials -o yaml --resource-group $RESOURCE_GROUP_AMS --account-name $MEDIA_SERVICE_NAME)
# fi

#capture config information
# re="AadTenantId:\s([0-9a-z\-]*)"
# AAD_TENANT_ID=$([[ "$AMS_CONNECTION" =~ $re ]] && echo ${BASH_REMATCH[1]})

# re="AadClientId:\s([0-9a-z\-]*)"
# AAD_SERVICE_PRINCIPAL_ID=$([[ "$AMS_CONNECTION" =~ $re ]] && echo ${BASH_REMATCH[1]})

# re="AadSecret:\s([0-9a-z\-]*)"
# AAD_SERVICE_PRINCIPAL_SECRET=$([[ "$AMS_CONNECTION" =~ $re ]] && echo ${BASH_REMATCH[1]})

# re="SubscriptionId:\s([0-9a-z\-]*)"
# SUBSCRIPTION_ID=$([[ "$AMS_CONNECTION" =~ $re ]] && echo ${BASH_REMATCH[1]})