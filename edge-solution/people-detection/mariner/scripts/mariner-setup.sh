#!/bin/bash
# Note: The script should be run as sudo

# Exit the script on any error
set -e

printHelp() {
    echo "
    Mandatory Arguments
        --rg-ams                : Resource group name for Azure Media Service, Storage Accounts and Web App
        
    Optional Arguments
        --rg-device             : Resource group name for brainbox and IoT Hub. If it's not provided, rg-ams is used 
        --website-password      : Password to access the web app
		--existing-iothub		: Name of existing IoT Hub
		--existing-device		: Name of existing IoT Edge device in IoT Hub
        --use-existing-sp       : Whether to use existing service principal
        --help                  : Show this message and exit
        --sp-id                 : Id of existing service principal     
        --sp-password           : secret of existing service principal
        --sp-object-id          : Object id of existing service principal 
    
    Examples:

    1. Deploy app with existing IoT Edge device
    sudo ./mariner-setup.sh --rg-ams rg-mariner-ams --rg-device rg-mariner-device --existing-iothub <iothub name> --existing-device <device name>

    2. Deploy app with existing Iot Edge device and existing Service Principal
    sudo ./mariner-setup.sh --rg-ams rg-mariner-ams --rg-device rg-mariner-device --existing-iothub <iothub name> --existing-device <device name> --use-existing-sp --sp-id <id> --sp-password <secret> --sp-object-id <object-id>

    2. Deploy app without existing IoT Edge device
    sudo ./mariner-setup.sh --rg-ams rg-mariner-ams --rg-device rg-mariner-device
    "

}

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


checkIfMachineIsMariner() {
	if [[ ! "$(uname -a)" == *"Mariner"* ]]; 
		then echo "[WARNING] Current machine is not a mariner build. The installation commands may not work." ;
	fi
}

checkPackageInstallation() {

	if [ -z "$(command -v iotedge)" ]; then
		echo "$(error) IoT Runtime is not installed in current machine"
		exitWithError
	fi

	if [ -z "$(command -v az)" ]; then
		checkIfMachineIsMariner
        echo "$(info) Installing az cli"
		wget "https://packages.microsoft.com/yumrepos/azure-cli/azure-cli-2.9.1-1.el7.x86_64.rpm"
		rpm -ivh --nodeps azure-cli-*.rpm
		rm azure-cli-*.rpm

		echo "$(info) Installing azure-iot extension"
        az extension add --name azure-iot
    else
		if [[ $(az extension list --query "[?name=='azure-iot'].name" --output tsv | wc -c) -eq 0 ]]; then
			echo "$(info) Installing azure-iot extension"
			az extension add --name azure-iot
		fi
	fi
	
    if [ -z "$(command -v jq)" ]; then
        checkIfMachineIsMariner
        echo "$(info) Installing jq"
		sudo yum -y install jq
    fi
	
    if [ -z "$(command -v iotedgedev)" ]; then
        echo "$(info) Installing iotedgedev"
		if [ -z "$(command -v pip3)" ];then
            sudo yum -y install python3-pip
        fi
        pip3 install iotedgedev    
    fi

	if [ -z "$(command -v timeout)" ]; then
        checkIfMachineIsMariner
        echo "$(info) Installing timeout"
		sudo yum -y install timeout
    fi
    
    echo "$(info) Updating jsonschema"
    pip3 install update jsonschema
}

WEBAPP_PASSWORD=""

while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --rg-ams)
            RESOURCE_GROUP_AMS="$2"
            shift # past argument
            shift # past value
            ;;
		--existing-iothub)
            IOTHUB_NAME="$2"
            shift # past argument
            shift # past value
            ;;
	    --existing-device)
            DEVICE_NAME="$2"
            shift # past argument
            shift # past value
            ;;
        --rg-device)
            RESOURCE_GROUP_DEVICE="$2"
            shift # past argument
            shift # past value
            ;;
        --use-existing-sp)
            USE_EXISTING_SP="True"
            shift # past argument
            ;;    
        --sp-id)
            SP_APP_ID="$2"
            shift # past argument
            shift # past value
            ;;
        --sp-password)
            SP_APP_PWD="$2"
            shift # past argument
            shift # past value
            ;;
        --sp-object-id)
            OBJECT_ID="$2"
            shift # past argument
            shift # past value
            ;;
        --website-password)
            WEBAPP_PASSWORD="$2"
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

# Check if required values are present after setting use existing service principal as Yes.
if [ "$USE_EXISTING_SP" == "True"  ];then
    if [ -z "$SP_APP_ID" ] || [ -z "$SP_APP_PWD" ] || [ -z "$OBJECT_ID" ];then
        echo "$(error) Service principal id, secret or object id must be provided with use-existing-sp"
        exitWithError
    else 
        echo "$(info) using provided existing service principal credentials"
    fi
else
    USE_EXISTING_SP="False"
    SP_APP_ID=""
    SP_APP_PWD=""
    OBJECT_ID=""
fi

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

# Run uname to get current device architecture
DEVICE_ARCHITECTURE="x86"
#Run command to get current device runtime
DEVICE_RUNTIME="CPU"

# Random number and string generation for unique names
RANDOM_SUFFIX="$(echo "$RESOURCE_GROUP_AMS" | md5sum | cut -c1-4)"
RANDOM_NUMBER="${RANDOM:0:3}"

if [ -z "$IOTHUB_NAME" ];then
    if [ ! -z "$DEVICE_NAME" ]; then
        echo "$(error) IOTHUB_NAME must be provided to use existing device /"$DEVICE_NAME/" "
    fi
	IOTHUB_NAME="brainboxhub"
	IOTHUB_NAME=${IOTHUB_NAME}${RANDOM_SUFFIX}
else
	USING_EXISTING_IOTHUB="Yes"
fi

# Check if device is present inside the existing iothub
if [ "$USING_EXISTING_IOTHUB" == "Yes" ];then
    if [ -z "$DEVICE_NAME" ];then
        echo "$(error) Device name cannot be empty while using existing iothub."
        exitWithError
    else 
        EXISTING_IOTHUB_DEVICE=$(az iot hub device-identity list --hub-name "$IOTHUB_NAME" --query "[?deviceId=='$DEVICE_NAME'].deviceId" -o tsv)
        if [ -z "$EXISTING_IOTHUB_DEVICE" ]; then
            echo "$(error) $DEVICE_NAME does not exists in the iothub $IOTHUB_NAME"
            exitWithError
        fi    
    fi
fi

if [ -z "$DEVICE_NAME" ]; then
	DEVICE_NAME="brainbox"
fi


MEDIA_SERVICE_NAME="livevideoanalysis"
MEDIA_SERVICE_NAME=${MEDIA_SERVICE_NAME}${RANDOM_SUFFIX}
#USE_EXISTING_RESOURCES="true"
LOCATION="westus2"
GRAPH_TOPOLOGY_NAME="CVRToAMSAsset"
GRAPH_INSTANCE_NAME="BrainBoxSOM"
STREAMING_LOCATOR="StreamingLocator"
STREAMING_LOCATOR=${STREAMING_LOCATOR}${RANDOM_SUFFIX}
DEPLOYMENT_NAME="bbox-deployment"
DEPLOYMENT_NAME=${DEPLOYMENT_NAME}${RANDOM_NUMBER}


#required credentials
TENANT_ID=$(az account show | jq '.tenantId')

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


# Downloading Mariner bundle
SAS_URL="https://unifiededgescenarios.blob.core.windows.net/mariner-deployment/deployment-bundle-mariner.zip"
echo "Downloading mariner bundle zip"

# Download the latest mariner-bundle.zip from storage account
wget -O mariner-bundle.zip "$SAS_URL"

# Extracts all the files from zip in curent directory;
# overwrite existing ones
echo "Unzipping the files"
unzip -o mariner-bundle.zip -d "mariner-bundle"
cd mariner-bundle

echo "Unzipped the files in directory mariner-bundle"

# Download ARM template and run from Az CLI

ARM_TEMPLATE="resources.json"
echo "Running ARM template"

ARM_DEPLOYMENT=$(az deployment sub create --location "$LOCATION" --template-file "$ARM_TEMPLATE" --no-prompt \
        --parameters resourceGroupDevice="$RESOURCE_GROUP_DEVICE" resourceGroupAMS="$RESOURCE_GROUP_AMS" iotHubName="$IOTHUB_NAME" mediaServiceName="$MEDIA_SERVICE_NAME" usingExistingIothub="$USING_EXISTING_IOTHUB")

STORAGE_BLOB_SHARED_ACCESS_SIGNATURE=$(echo "$ARM_DEPLOYMENT" | jq -r '.properties.outputs.sasToken.value')

printf "\n%60s\n" " " | tr ' ' '-'
echo "Configuring Edge Device in IoT Hub"
printf "%60s\n" " " | tr ' ' '-'

# The following steps retrieves the connection string for the edge device an uses it to onboard
# the device using sshpass. This step may fail if the edge device's network firewall
# does not allow ssh access. Please make sure the edge device is on the local area
# network and is accepting ssh requests.
EXISTING_IOTHUB_DEVICE=$(az iot hub device-identity list --hub-name "$IOTHUB_NAME" --query "[?deviceId=='$DEVICE_NAME'].deviceId" -o tsv)

if [ -z "$EXISTING_IOTHUB_DEVICE" ]; then
    echo "$(info) Creating an Edge device \"$DEVICE_NAME\" in IoT Hub \"$IOTHUB_NAME\""
    az iot hub device-identity create --hub-name "$IOTHUB_NAME" --device-id "$DEVICE_NAME" --edge-enabled --output "none"
    echo "$(info) Created \"$DEVICE_NAME\" device in IoT Hub \"$IOTHUB_NAME\""
	echo "$(info) Retrieving connection string for device \"$DEVICE_NAME\" from Iot Hub \"$IOTHUB_NAME\" and updating the IoT Edge service in edge device with this connection string"
	EDGE_DEVICE_CONNECTION_STRING=$(az iot hub device-identity connection-string show --device-id "$DEVICE_NAME" --hub-name "$IOTHUB_NAME" --query "connectionString" -o tsv)
	echo "$(info) Updating Config.yaml on edge device with the connection string from IoT Hub"
	SCRIPT_PATH="configedge.sh"
	# Replace placeholder connection string with actual value for Edge device using the 'configedge.sh' script
	source "$SCRIPT_PATH" "$EDGE_DEVICE_CONNECTION_STRING"
	echo "$(info) Updated Config.yaml"
fi

# creating new service principal for custom role assignment

if [ "$USE_EXISTING_SP" == "False" ];then 
    APP_NAME="$MEDIA_SERVICE_NAME-sp"
    APP_DETAILS=$(az ad sp create-for-rbac --name $APP_NAME --skip-assignment --query "{appName:displayName, appId:appId, appSecret:password}")
    OBJECT_ID=$(az ad sp list --display-name $APP_NAME --query [0].objectId --output tsv)
    SP_APP_ID=$(echo $APP_DETAILS | jq -r '.appId')
    SP_APP_PWD=$(echo $APP_DETAILS | jq -r '.appSecret')
fi

# Download ARM template and run from Az CLI

ARM_TEMPLATE="custom-role.json"
echo "Running ARM template"
ROLE_ASSIGNMENT=$(az deployment sub create --location "$LOCATION" --template-file "$ARM_TEMPLATE" --no-prompt \
        --parameters servicePrincipalObjectId="$OBJECT_ID" resourceGroupAMS="$RESOURCE_GROUP_AMS")


MANIFEST_TEMPLATE_NAME="deployment.lvaazureeye.template.json"
MANIFEST_ENVIRONMENT_VARIABLES_FILENAME=".env"

CUSTOM_VIDEO_SOURCE="https://unifiededgescenarios.blob.core.windows.net/mariner-deployment/staircase.mkv"
sudo wget -O "staircase.mkv" "$CUSTOM_VIDEO_SOURCE" -P /home/lvaadmin/samples/input/


# Check for existence of IoT Hub and Edge device in Resource Group for IoT Hub,
# and based on that either throw error or use the existing resources
if [ -z "$(az iot hub list --query "[?name=='$IOTHUB_NAME'].name" --resource-group "$RESOURCE_GROUP_DEVICE" -o tsv)" ]; then
    echo "$(error) IoT Hub \"$IOTHUB_NAME\" does not exist."
    exit 1
else
    echo "$(info) Using existing IoT Hub \"$IOTHUB_NAME\""
fi

if [ -z "$(az iot hub device-identity list --hub-name "$IOTHUB_NAME" --resource-group "$RESOURCE_GROUP_DEVICE" --query "[?deviceId=='$DEVICE_NAME'].deviceId" -o tsv)" ]; then
    echo "$(error) Device \"$DEVICE_NAME\" does not exist in IoT Hub \"$IOTHUB_NAME\""
    exit 1
else
    echo "$(info) Using existing Edge Device \"$IOTHUB_NAME\""
fi

MANIFEST_TEMPLATE_NAME="deployment.lvaedge.template.json"
MANIFEST_ENVIRONMENT_VARIABLES_FILENAME=".env"


# Update the value of RUNTIME variable in environment variable file
sed -i 's#^\(SP_APP_ID[ ]*=\).*#\1\"'"$SP_APP_ID"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
sed -i 's#^\(SP_APP_PWD[ ]*=\).*#\1\"'"$SP_APP_PWD"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
sed -i 's#^\(TENANT_ID[ ]*=\).*#\1\"'"$TENANT_ID"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
sed -i 's#^\(SUBSCRIPTION_ID[ ]*=\).*#\1\"'"$SUBSCRIPTION_ID"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
sed -i 's#^\(AMS_ACCOUNT_NAME[ ]*=\).*#\1\"'"$MEDIA_SERVICE_NAME"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
sed -i 's#^\(RESOURCE_GROUP_AMS[ ]*=\).*#\1\"'"$RESOURCE_GROUP_AMS"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"


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

echo "$(info) Pausing script for 13m to allow Edge modules to start."
sleep 13m

# Create an AMS asset
echo "$(info) Creating an asset on AMS"
ASSET="$GRAPH_TOPOLOGY_NAME-$GRAPH_INSTANCE_NAME"
az ams asset create --account-name "$MEDIA_SERVICE_NAME" --name "$ASSET" --resource-group "$RESOURCE_GROUP_AMS" --output "none"
echo "$(info) Setting LVA graph topology"

GRAPH_TOPOLOGY=$(
    < cvr-topology.json jq '.name = "'"$GRAPH_TOPOLOGY_NAME"'"'
)

az iot hub invoke-module-method \
    -n "$IOTHUB_NAME" \
    -d "$DEVICE_NAME" \
    -m lvaEdge \
    --mn GraphTopologySet \
    --mp "$GRAPH_TOPOLOGY" \
    --output "none"

echo "$(info) Getting LVA graph topology status"
TOPOLOGY_STATUS=$(az iot hub invoke-module-method -n "$IOTHUB_NAME" -d "$DEVICE_NAME" -m lvaEdge --mn GraphTopologyList \
    --mp '{"@apiVersion": "1.0","name": "'"$GRAPH_TOPOLOGY_NAME"'"}')

if [ "$(echo "$TOPOLOGY_STATUS" | jq '.status')" == 200 ]; then
    echo "$(info) Graph Topology has been set on device"
else
    echo "$(error) Graph Topology has not been set on device"
    exitWithError
fi


echo "$(info) Creating a new LVA graph instance"

GRAPH_INSTANCE=$(
    < cvr-topology-params.json jq '.name = "'"$GRAPH_INSTANCE_NAME"'"' | jq '.properties.topologyName = "'"$GRAPH_TOPOLOGY_NAME"'"'
)

echo "$(info) Setting LVA graph instance"

az iot hub invoke-module-method \
    -n "$IOTHUB_NAME" \
    -d "$DEVICE_NAME" \
    -m lvaEdge \
    --mn GraphInstanceSet \
    --mp "$GRAPH_INSTANCE" \
    --output "none"


echo "$(info) Getting LVA graph instance status"
INSTANCE_STATUS=$(az iot hub invoke-module-method -n "$IOTHUB_NAME" -d "$DEVICE_NAME" -m lvaEdge --mn GraphInstanceList \
    --mp '{"@apiVersion": "1.0","name": "'"$GRAPH_INSTANCE_NAME"'"}')

if [ "$(echo "$INSTANCE_STATUS" | jq '.status')" == 200 ]; then
    echo "$(info) Graph Instance has been created on device."
else
    echo "$(error) Graph Instance has not been created on device"
    exitWithError
fi


echo "$(info) Activating LVA graph instance"
INSTANCE_RESPONSE=$(az iot hub invoke-module-method \
    -n "$IOTHUB_NAME" \
    -d "$DEVICE_NAME" \
    -m lvaEdge \
    --mn GraphInstanceActivate \
    --mp '{"@apiVersion" : "1.0","name" : "'"$GRAPH_INSTANCE_NAME"'"}')


if [ "$(echo "$INSTANCE_RESPONSE" | jq '.status')" == 200 ]; then
    echo "$(info) Graph Instance has been activated on device."
else
    echo "$(error) Failed to activate Graph Instance on device."
    echo "ERROR CODE: $(echo "$INSTANCE_RESPONSE" | jq '.payload.error.code')"
    echo "ERROR MESSAGE: $(echo "$INSTANCE_RESPONSE" | jq '.payload.error.message')"
    exitWithError
fi

echo "$(info) Pausing script execution for 3m"
sleep 3m
echo "$(info) Restarting the lvaEdge module on edge device"
RESTART_MODULE=$(az iot hub invoke-module-method --method-name "RestartModule" -n "$IOTHUB_NAME" -d "$DEVICE_NAME" -m \$edgeAgent --method-payload \
'{"schemaVersion": "1.0","id": "lvaEdge"}')

if [ "$(echo "$RESTART_MODULE" | jq '.status')" == 200 ]; then
        echo "$(info) Restarted the lvaEdge module on edge device"
else
    echo "$(error) Failed to restart the lvaEdge module on edge device."
    echo "ERROR CODE: $(echo "$INSTANCE_RESPONSE" | jq '.payload.error.code')"
    echo "ERROR MESSAGE: $(echo "$INSTANCE_RESPONSE" | jq '.payload.error.message')"
    exitWithError
fi

echo "$(info) Pausing script execution for 3m"
sleep 3m

if [ "$ASSET" == "$GRAPH_TOPOLOGY_NAME"-"$GRAPH_INSTANCE_NAME" ]; then

    if [ "$(az ams streaming-locator show --account-name "$MEDIA_SERVICE_NAME" -g "$RESOURCE_GROUP_AMS" --name "$STREAMING_LOCATOR" --query "name" -o tsv)" == "$STREAMING_LOCATOR" ]; then
        echo "$(info) Streaming Locator already exist"
        echo "$(info) Deleting the existing Streaming Locator..."
        az ams streaming-locator delete --account-name "$MEDIA_SERVICE_NAME" -g "$RESOURCE_GROUP_AMS" --name "$STREAMING_LOCATOR" --output "none"
                echo "$(info) Deleted the existing Streaming Locator"
    fi

    sleep 10s

    #creating streaming locator for video playback
    echo "$(info) Creating Streaming Locator..."
    az ams streaming-locator create --account-name "$MEDIA_SERVICE_NAME" --asset-name "$GRAPH_TOPOLOGY_NAME-$GRAPH_INSTANCE_NAME" --name "$STREAMING_LOCATOR" --resource-group "$RESOURCE_GROUP_AMS" --streaming-policy-name "Predefined_ClearStreamingOnly" --output "none"
        echo "$(info) Created Streaming Locator"

else
    echo "$(error) AMS Asset not found"
    exitWithError
fi

# Start the Streaming Endpoint of media service
echo "$(info) Starting the Streaming endpoint..."
az ams streaming-endpoint start --account-name "$MEDIA_SERVICE_NAME" --name "default" --resource-group "$RESOURCE_GROUP_AMS" --output "none"
echo "$(info) Started the Streaming endpoint"
echo "$(info) Pausing script execution for 2m"
sleep 2m

# Passing Streaming url to script output for video playback
STREAMING_ENDPOINT_HOSTNAME=$(az ams streaming-endpoint show --account-name "$MEDIA_SERVICE_NAME" --resource-group "$RESOURCE_GROUP_AMS" -n "default" --query "hostName" -o tsv)

# Checking the existence of Streaming path on Media Service
# till Max 15 minutes
for ((i=1; i<=60; i++)); do
    STREAMING_PATH=$(az ams streaming-locator get-paths -a "$MEDIA_SERVICE_NAME" -g "$RESOURCE_GROUP_AMS" -n "$STREAMING_LOCATOR" --query "streamingPaths[?streamingProtocol=='SmoothStreaming'].paths[]" -o tsv)
    if [ -z "$STREAMING_PATH" ]; then
        sleep 15s
    else
        break
    fi
done

if [ -z "$STREAMING_PATH" ];then
    echo "$(error) Streaming path is not available"
    exitWithError
fi

STREAMING_URL="https://$STREAMING_ENDPOINT_HOSTNAME$STREAMING_PATH"

MODULE_CONNECTION_STRING=$(az iot hub module-identity connection-string show --device-id "$DEVICE_NAME" --module-id lvaYolov3 --hub-name "$IOTHUB_NAME" --key-type primary --query "connectionString" -o tsv)

echo "$(info) Running ARM template to deploy Web App"

PACKAGE_URI="https://unifiededgescenarios.blob.core.windows.net/mariner-deployment/people-detection-app.zip"

WEBAPP_TEMPLATE="webapp.json"

APP_DEPLOYMENT=$(az deployment group create --resource-group "$RESOURCE_GROUP_AMS" --template-file "$WEBAPP_TEMPLATE" --no-prompt --parameters password="$WEBAPP_PASSWORD" existingIotHubName="$IOTHUB_NAME" AMP_STREAMING_URL="$STREAMING_URL" AZUREEYE_MODULE_CONNECTION_STRING="$MODULE_CONNECTION_STRING" STORAGE_BLOB_SHARED_ACCESS_SIGNATURE="$STORAGE_BLOB_SHARED_ACCESS_SIGNATURE" WEBAPP_PACKAGE="$PACKAGE_URI")

WEBAPP_NAME=$(az resource list --resource-group "$RESOURCE_GROUP_AMS" --query "[?type=='Microsoft.Web/sites'].name" -o tsv)
WEBAPP_URL="https://$WEBAPP_NAME.azurewebsites.net"
echo "$(info) Script execution is completed successfully. You can visit the web app at the following link."
echo "$(info) Web App: $WEBAPP_URL"