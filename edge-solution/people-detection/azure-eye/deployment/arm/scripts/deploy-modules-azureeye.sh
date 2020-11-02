#!/bin/bash

# This script generates a deployment manifest template and deploys it to an existing IoT Edge device

echo "Logging in with Managed Identity"
az login --identity --output "none"

# Define helper function for logging
info() {
    echo "$(date +"%Y-%m-%d %T") [INFO]"
}

# Define helper function for logging. This will change the Error text color to red
error() {
    echo "$(tput setaf 1)$(date +"%Y-%m-%d %T") [ERROR]"
}

exitWithError() {
    # Reset console color
    tput sgr0
    exit 1
}

SAS_URL="https://unifiededgescenariostest.blob.core.windows.net/test/manifest-bundle-azureeye.zip"

# Download the latest manifest-bundle.zip from storage account
wget -O manifest-bundle.zip "$SAS_URL"

echo "Downloading is done for latest files"

# Extracts all the files from zip in curent directory;
# overwrite existing ones
echo "Unzipping the files"
unzip -o manifest-bundle.zip -d "manifest-bundle"
cd manifest-bundle
echo "Unzipped the files in directory manifest-bundle"


echo "Installing packages"

echo "Installing iotedgedev"
pip install iotedgedev==2.1.4

echo "Updating az-cli"
pip install --upgrade azure-cli
pip install --upgrade azure-cli-telemetry

echo "installing azure iot extension"
az extension add --name azure-iot

pip3 install --upgrade jsonschema
apk add coreutils
apk add sshpass
echo "Installation complete"

# We're enabling exit on error after installation steps as there are some warnings and error thrown in installation steps which causes the script to fail
set -e

# Check for existence of IoT Hub and Edge device in Resource Group for IoT Hub,
# and based on that either throw error or use the existing resources
if [ -z "$(az iot hub list --query "[?name=='$IOTHUB_NAME'].name" --resource-group "$RESOURCE_GROUP_IOT" -o tsv)" ]; then
    echo "$(error) IoT Hub \"$IOTHUB_NAME\" does not exist."
    exit 1
else
    echo "$(info) Using existing IoT Hub \"$IOTHUB_NAME\""
fi

IOTHUB_CONNECTION_STRING="$(az iot hub connection-string show --hub-name "$IOTHUB_NAME" --query "connectionString" --output tsv)"

if [ -z "$(az iot hub device-identity list --hub-name "$IOTHUB_NAME" --resource-group "$RESOURCE_GROUP_IOT" --query "[?deviceId=='$DEVICE_NAME'].deviceId" -o tsv)" ]; then
    echo "$(error) Device \"$DEVICE_NAME\" does not exist in IoT Hub \"$IOTHUB_NAME\""
    exit 1
else
    echo "$(info) Using existing Edge Device \"$IOTHUB_NAME\""
fi

EDGE_DEVICE_CONNECTION_STRING=$(az iot hub device-identity connection-string show --device-id "$DEVICE_NAME" --hub-name "$IOTHUB_NAME" --query "connectionString" -o tsv)

MANIFEST_TEMPLATE_NAME="deployment.lvaazureeye.template.json"
MANIFEST_ENVIRONMENT_VARIABLES_FILENAME=".env"

# Update the value of RUNTIME variable in environment variable file
sed -i 's#^\(AAD_SERVICE_PRINCIPAL_ID[ ]*=\).*#\1\"'"$SP_APP_ID"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
sed -i 's#^\(AAD_SERVICE_PRINCIPAL_SECRET[ ]*=\).*#\1\"'"$SP_APP_PWD"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
sed -i 's#^\(AAD_TENANT_ID[ ]*=\).*#\1\"'"$TENANT_ID"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
sed -i 's#^\(SUBSCRIPTION_ID[ ]*=\).*#\1\"'"$SUBSCRIPTION_ID"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
sed -i 's#^\(AMS_ACCOUNT[ ]*=\).*#\1\"'"$AMS_ACCOUNT_NAME"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
sed -i 's#^\(RESOURCE_GROUP[ ]*=\).*#\1\"'"$RESOURCE_GROUP_IOT"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
sed -i 's#^\(IOT_DEVICE_ID[ ]*=\).*#\1\"'"$DEVICE_NAME"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
sed -i 's#^\(IOT_HUB_CONN_STRING[ ]*=\).*#\1\"'"$IOTHUB_CONNECTION_STRING"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
sed -i 's#^\(IOT_EDGE_DEVICE_CONN_STRING[ ]*=\).*#\1\"'"$EDGE_DEVICE_CONNECTION_STRING"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"


echo "$(info) Generating manifest file from template file"
# Generate manifest file
iotedgedev genconfig --file "$MANIFEST_TEMPLATE_NAME"

echo "$(info) Generated manifest file"

#Construct file path of the manifest file by getting file name of template file and replace 'template.' with '' if it has .json extension
#iotedgedev service used deployment.json filename if the provided file does not have .json extension
#We are prefixing ./config to the filename as iotedgedev service creates a config folder and adds the manifest file in that folder

# if .json then remove template. if present else deployment.json
if [[ "$MANIFEST_TEMPLATE_NAME" == *".json"* ]]; then
    # Check if the file name is like name.template.json, if it is construct new name as name.json
    # Remove last part (.json) from file name
    TEMPLATE_FILE_NAME="${MANIFEST_TEMPLATE_NAME%.*}"
    # Get the last part form file name and check if it is template
    IS_TEMPLATE="${TEMPLATE_FILE_NAME##*.}"
    if [ "$IS_TEMPLATE" == "template" ]; then
        # Get everything but the last part (.template) and append .json to construct new name
        TEMPLATE_FILE_NAME="${TEMPLATE_FILE_NAME%.*}.json"
        PRE_GENERATED_MANIFEST_FILENAME="./config/$(basename "$TEMPLATE_FILE_NAME")"
    else
        PRE_GENERATED_MANIFEST_FILENAME="./config/$(basename "$MANIFEST_TEMPLATE_NAME")"
    fi
else
    PRE_GENERATED_MANIFEST_FILENAME="./config/deployment.json"
fi

if [ ! -f "$PRE_GENERATED_MANIFEST_FILENAME" ]; then
    echo "$(error) Manifest file \"$PRE_GENERATED_MANIFEST_FILENAME\" does not exist. Please check config folder under current directory: \"$PWD\" to see if manifest file is generated or not"
fi


# This step deploys the configured deployment manifest to the edge device. After completed,
# the device will begin to pull edge modules and begin executing workloads (including sending
# messages to the cloud for further processing, visualization, etc).
# Check if a deployment with given name, already exists in IoT Hub. If it doesn't exist create a new one.
# If it exists, append a random number to user given deployment name and create a deployment.

az iot edge deployment create --deployment-id "$DEPLOYMENT_NAME" --hub-name "$IOTHUB_NAME" --content "$PRE_GENERATED_MANIFEST_FILENAME" --target-condition "deviceId='$DEVICE_NAME'" --output "none"

echo "$(info) Deployed manifest file to IoT Hub. Your modules are being deployed to your device now. This may take some time."

sleep 8m

echo "$(info) Setting LVA graph topology..."
GRAPH_TOPOLOGY=$(
    cat cvr-topology.json | 
    jq '.name = "CVRToAMSAsset"'
)

az iot hub invoke-module-method \
    -n $IOTHUB_NAME \
    -d $DEVICE_NAME \
    -m lvaEdge \
    --mn GraphTopologySet \
    --mp "$GRAPH_TOPOLOGY"
#     '
#     {
#         "@apiVersion": "1.0"
#     }
#     '


echo "$(info) Creating new LVA graph instance..."

# Getting rtsp url from Manifest Environment variable file (.env) 
RTSP_URL=$(grep -w "RTSP_URL" ".env" | cut -d'=' -f2)

GRAPH_INSTANCE=$(
    cat cvr-topology-params.json | 
    jq '.name = "AzureEyeSOM"' | 
    jq '.properties.topologyName = "CVRToAMSAsset"' | 
    jq --arg replace_value "$RTSP_URL" '.properties.parameters[0].value = $replace_value'
)

az iot hub invoke-module-method \
    -n $IOTHUB_NAME \
    -d $DEVICE_NAME \
    -m lvaEdge \
    --mn GraphInstanceSet \
    --mp "$GRAPH_INSTANCE"

#

echo "$(info) Activating LVA graph instance..."
az iot hub invoke-module-method \
    -n $IOTHUB_NAME \
    -d $DEVICE_NAME \
    -m lvaEdge \
    --mn GraphInstanceActivate \
    --mp \
        '
            {
                "@apiVersion" : "1.0",
                "name" : "AzureEyeSOM"
            }
        '

# 


#creating streaming endpoint
az ams streaming-endpoint create --account-name "$AMS_ACCOUNT_NAME" --name "endpoint-1" --resource-group "$RESOURCE_GROUP_IOT" --scale-units 0

#starting streaming endpoint
az ams streaming-endpoint start --account-name "$AMS_ACCOUNT_NAME" --name "endpoint-1" --resource-group "$RESOURCE_GROUP_IOT"

#creating streaming locator for video playback
az ams streaming-locator create --account-name "$AMS_ACCOUNT_NAME" --asset-name "CVRToAMSAsset-AzureEyeSOM" --name "locator-1" --resource-group "$RESOURCE_GROUP_IOT" --streaming-policy-name "Predefined_ClearStreamingOnly"