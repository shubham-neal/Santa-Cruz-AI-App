#!/usr/bin/env bash

# stop execution on error from azure cli
set -e


# Read variable values from variables.template file in current directory
source variables.template

# Define helper function for logging
timestamp()
{
    date +"%Y-%m-%d %T"
}

# Log into Azure
printf "\n%60s\n" " " | tr ' ' '-'
echo "Logging into Azure Subscription"
printf "%60s\n" " " | tr ' ' '-'

# This step checks the value for USE_INTERACTIVE_LOGIN_FOR_AZURE.
# If the value is true, the script will allow 
if [ "$USE_INTERACTIVE_LOGIN_FOR_AZURE" == "true" ]; then
	echo "$(timestamp) [INFO] Attempting login"
	az login --tenant $TENANT_ID
	echo "[INFO] Login Successful"
else
	echo "$(timestamp) [INFO] Attempting Login with Service Principal Account"
	# Using service principal as it will not require user interaction
	az login --service-principal --username $SP_APP_ID --password $SP_APP_PWD --tenant $TENANT_ID

	echo "[INFO] Login Successful"
fi

# Set Azure Subscription
printf "\n%60s\n" " " | tr ' ' '-'
echo "Connecting to Azure Subscription"
printf "%60s\n" " " | tr ' ' '-'

echo "$(timestamp) [INFO] Setting current subscription to: $SUBSCRIPTION_ID"
az account set --subscription $SUBSCRIPTION_ID
echo "$(timestamp) [INFO] Successfully Set subscription to $SUBSCRIPTION_ID"

# Create a new resource group if it does not exist already. 
# If it already exists then check value for USE_EXISTING_RG 
# and based on that either throw error or use the existing RG
printf "\n%60s\n" " " | tr ' ' '-' 
echo Configuring Resource Group
printf "%60s\n" " " | tr ' ' '-'


if [ $(az group exists --name $RESOURCE_GROUP) == false ]; then
	echo "$(timestamp) [INFO] Creating a new Resource Group: $RESOURCE_GROUP"   
	az group create --name $RESOURCE_GROUP --location "$LOCATION"
	echo "$(timestamp) [INFO] Successfully created resource group"

    else
        if [ "$USE_EXISTING_RG" == "true" ]; then
           echo "$(timestamp) [INFO] Using Existing Resource Group: $RESOURCE_GROUP"
        else
			echo "$(timestamp) [ERROR] $RESOURCE_GROUP already exists"
			exit 1
        fi
fi

# We are checking if the IoTHub already exists by querying the list of IoT Hubs in current context.
# It will return a blank array if it does not exist. Create a new IoT Hub if it does not exist, 
# if it already exists then check value for USE_EXISTING_IOT_HUB and based on that either throw error 
# or use the existing IoT Hub
printf "\n%60s\n" " " | tr ' ' '-'
echo Configuring IoT Hub
printf "%60s\n" " " | tr ' ' '-'


EXISTING_IOTHUB=$(az iot hub list --query "[?name=='$IOTHUB_NAME'].{Name:name}" --output tsv)

if [ -z $EXISTING_IOTHUB ]; then
		echo "$(timestamp) [INFO] Creating a new IoT Hub"
		az iot hub create --name "$IOTHUB_NAME" --sku S1 --resource-group "$RESOURCE_GROUP"
		echo "$(timestamp) [INFO] Created a new IoT hub"
    else
         if [ "$USE_EXISTING_IOT_HUB" == "true" ]; then
                echo "$(timestamp) [INFO] Using existing IoT Hub $IOTHUB_NAME"
        else
                echo "$(timestamp) [ERROR] $IOTHUB_NAME already exists"
				exit 1
        fi
fi


# Adding default route in IoT hub. This is used to retrieve messages from Iot Hub
# as they are generated. 
EXISTING_DEFAULT_ROUTE=$(az iot hub route list --hub-name $IOTHUB_NAME --resource-group $RESOURCE_GROUP --query "[?name=='defaultroute'].name" --output tsv)
if [ -z $EXISTING_DEFAULT_ROUTE ]; then
    echo "$(timestamp) [INFO] Creating default IoT Hub route"	
    az iot hub route create --name "defaultroute" --hub-name $IOTHUB_NAME --source devicemessages   --resource-group $RESOURCE_GROUP   --endpoint-name "events"   --enabled   --condition "true"
fi


# Adding route to send messages to ADLS. This step creates an Azure Data Lake Storage account,
# and creates routing endpoints and routes in Iot Hub. Messages will spill into a data lake
# every one minute.
if [ "$PUSH_RESULTS_TO_ADLS" == "true" ]; then
    echo "$(timestamp) [INFO] Creating a storage account"
    #create storage account with hierarchical namespace enabled:
    az storage account create  --name $STORAGE_ACCOUNT_NAME  --resource-group $RESOURCE_GROUP     --location "$LOCATION"     --sku Standard_RAGRS     --kind StorageV2     --enable-hierarchical-namespace true
    # create a container:
    echo "$(timestamp) [INFO] Creating a storage container"
    STORAGE_ACCOUNT_KEY=$(az storage account keys list     --resource-group $RESOURCE_GROUP     --account-name $STORAGE_ACCOUNT_NAME     --query "[0].value" | tr -d '"') 
    az storage container create --name $BLOBCONTAINER_NAME     --account-name $STORAGE_ACCOUNT_NAME     --account-key $STORAGE_ACCOUNT_KEY     --public-access off
    
    #get connection string for storage account:
    STORAGE_CONNECTION_STRING=$(az storage account show-connection-string   -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME --query connectionString -o tsv)
    
    echo "$(timestamp) [INFO] Creating a custom endpoint in IoT Hub for ADLS" 
    #create a custom-endpoint  to data lake:
    az iot hub routing-endpoint create --resource-group $RESOURCE_GROUP --hub-name $IOTHUB_NAME --endpoint-name $ADLS_ENDPOINT_NAME --endpoint-type azurestoragecontainer --endpoint-resource-group $RESOURCE_GROUP --endpoint-subscription-id $SUBSCRIPTION_ID --connection-string $STORAGE_CONNECTION_STRING --container-name "$BLOBCONTAINER_NAME" --batch-frequency 60 --chunk-size 100 --encoding json --ff  {iothub}/{partition}/{YYYY}/{MM}/{DD}/{HH}/{mm}
    
    echo "$(timestamp) [INFO] Creating a route in IoT Hub for ADLS custom endpoint"
    # Create a route for storage endpoint.	
    az iot hub route create   --name $IOTHUB_ADLS_ROUTENAME   --hub-name $IOTHUB_NAME   --source devicemessages   --resource-group $RESOURCE_GROUP   --endpoint-name $ADLS_ENDPOINT_NAME   --enabled   --condition "$ADLS_ROUTING_CONDITION"

fi


# Adding route to send messages to an Event Hub namespace. This step creates an Event Hub and namespace,
# and creates routing endpoints and routes in Iot Hub. Messages will spill into a data lake
# every one minute.
if [ "$PUSH_RESULTS_TO_EVENT_HUB" == "true" ]; then
    
    echo "$(timestamp) [INFO] Creating Event Hub namespace"
        #create event hub namespace
        az eventhubs namespace create --name $EVENTHUB_NAMESPACE   --resource-group $RESOURCE_GROUP  -l "$LOCATION"

    echo "$(timestamp) [INFO] Creating Event Hub"
        #create a event hub in namespace
        az eventhubs eventhub create --name $EVENTHUB_NAME --resource-group $RESOURCE_GROUP  --namespace-name $EVENTHUB_NAMESPACE

    echo "$(timestamp) [INFO] Creating a Shared Access Policy for Event Hub"   
        #create shared access auth rule and get the connection string
        az eventhubs eventhub authorization-rule create --resource-group $RESOURCE_GROUP  --namespace-name $EVENTHUB_NAMESPACE  --eventhub-name $EVENTHUB_NAME  --name RootManageSharedAccessKey  --rights Manage Send Listen
        EVENTHUB_CONNECTION_STRING=$(az eventhubs eventhub  authorization-rule keys list --resource-group "$RESOURCE_GROUP" --namespace-name "$EVENTHUB_NAMESPACE"  --eventhub-name "$EVENTHUB_NAME"  --name RootManageSharedAccessKey --query "primaryConnectionString" -o  tsv)

    echo "$(timestamp) [INFO] Creating a custom endpoint in IoT Hub for Event Hub"
        #create an endpoint for event hub:
        az iot hub routing-endpoint create --resource-group $RESOURCE_GROUP --hub-name $IOTHUB_NAME  --endpoint-name $EVENTHUB_ENDPOINT_NAME --endpoint-type eventhub  --endpoint-resource-group $RESOURCE_GROUP --endpoint-subscription-id $SUBSCRIPTION_ID  --connection-string $EVENTHUB_CONNECTION_STRING

    echo "$(timestamp) [INFO] Creating a route in IoT Hub for Event Hub custom endpoint"
        #create route for event hub in Iot hub:(Actual condition :"\$twin.moduleid = 'camerastream' and type = 'image'" )
        az iot hub route create   --name $EVENTHUB_ROUTENAME   --hub-name $IOTHUB_NAME   --source devicemessages   --resource-group $RESOURCE_GROUP   --endpoint-name $EVENTHUB_ENDPOINT_NAME   --enabled   --condition "$EVENTHUB_ROUTING_CONDITION"

fi


# This step creates a new edge device in the IoT Hub account or will use an existing edge device
# if the USE_EXISTING_IOT_HUB_DEVICE configuration variable is set to true. 
printf "\n%60s\n" " " | tr ' ' '-'
echo Configuring Edge Device in IoT Hub
printf "%60s\n" " " | tr ' ' '-'

EXISTING_IOTHUB_DEVICE=$(az iot hub device-identity list --hub-name "$IOTHUB_NAME" --query "[?deviceId=='$DEVICE_NAME'].deviceId" -o tsv)
if [ -z $EXISTING_IOTHUB_DEVICE ]; then
    echo "$(timestamp) [INFO] Creating an Edge device in IoT Hub"	
    az iot hub device-identity create --hub-name "$IOTHUB_NAME" --device-id "$DEVICE_NAME" --edge-enabled
    echo "$(timestamp) [INFO] Created $DEVICE_NAME device in IoT Hub $IOTHUB_NAME"
else
    if [ "$USE_EXISTING_IOT_HUB_DEVICE" == "true" ]; then
        echo "$(timestamp) [INFO] Using existing IoT Hub Edge Device $DEVICE_NAME"
    else
        echo "$(timestamp) [ERROR] $DEVICE_NAME already exists in IoT Hub $IOTHUB_NAME"
        exit 1
    fi	
fi

if [ "$CREATE_AZURE_MONITOR" == "true" ]; then
	echo "$(timestamp) [INFO] Retrieve resource id for IoT Hub"

	IOTHUB_RESOURCE_ID=$(az iot hub list --query "[?name=='$IOTHUB_NAME'].{resourceID:id}" --output tsv)

	echo "$(timestamp) [INFO] Creating an Azure Monitor"

	AZ_MONITOR_SP=$(az ad sp create-for-rbac --role="Monitoring Metrics Publisher" --name $AZURE_MONITOR_SP_NAME --scopes=$IOTHUB_RESOURCE_ID)
	TELEGRAF_AZURE_TENANT_ID=$TENANT_ID
	TELEGRAF_AZURE_CLIENT_ID=$(echo "$AZ_MONITOR_SP" | jq -r '.appId')
	TELEGRAF_AZURE_CLIENT_SECRET=$(echo "$AZ_MONITOR_SP" | jq -r '.password')

	echo "$(timestamp) [INFO] Azure Monitor creation is complete"
fi

# This step retreives the connection string for the edge device an uses it to onboard
# the device using sshpass. This step may fail if the edge device's network firewall
# does not allow ssh access. Please make sure the edge device is on the local area
# network and is accepting ssh requests.
echo "$(timestamp) [INFO] Retrieving connection string for device $DEVICE_NAME from Iot Hub $IOTHUB_NAME and updating the IoT Edge service in edge device with this connection string"

EDGE_DEVICE_CONNECTION_STRING=$(az iot hub device-identity show-connection-string --device-id "$DEVICE_NAME" --hub-name "$IOTHUB_NAME" --query "connectionString" -o tsv )

echo "$(timestamp) [INFO] Updating Config.yaml on edge device with the connection string from IoT Hub"

CONFIG_FILE_PATH="/etc/iotedge/config.yaml"

# Replace placeholder connection string with actual value for Edge device
# Using sshpass and ssh to update the value on Edge device

if [ "$IS_THE_SCRIPT_RUNNING_FROM_EDGE_DEVICE" == "true" ]; then
	sudo sed -i -e '/device_connection_string:/ s#\"[^\"][^\"]*\"#\"$EDGE_DEVICE_CONNECTION_STRING\"#' $CONFIG_FILE_PATH
		
	echo "$(timestamp) [INFO] Config.yaml update is complete"
	echo "$(timestamp) [INFO] Restarting IoT Edge service"
	sudo systemctl restart iotedge
	echo "$(timestamp) [INFO] IoT Edge service restart is complete"
	
else
	Command="sudo sed -i -e '/device_connection_string:/ s#\"[^\"][^\"]*\"#\"$EDGE_DEVICE_CONNECTION_STRING\"#' $CONFIG_FILE_PATH"
	sshpass -p $EDGE_DEVICE_PASSWORD ssh $EDGE_DEVICE_USERNAME@$EDGE_DEVICE_IP -o StrictHostKeyChecking=no "$Command"

	echo "$(timestamp) [INFO] Config.yaml update is complete"
	echo "$(timestamp) [INFO] Restarting IoT Edge service"

	# Restart the service on Edge device 
	sshpass -p $EDGE_DEVICE_PASSWORD ssh $EDGE_DEVICE_USERNAME@$EDGE_DEVICE_IP -o StrictHostKeyChecking=no "sudo systemctl restart iotedge"
	echo "$(timestamp) [INFO] IoT Edge service restart is complete"
fi


# This step uses the iotedgedev cli toolkit to inject defined environment variables into a predefined deployment manifest JSON 
# file. Once an environment specific manifest has been generated, the script will deploy to the identified edge device. A pre-generated 
# manifest file can also be provided by the user, in which case a manifest file will not be generated by the iotedgedev service.
if [ -z $PRE_GENERATED_MANIFEST_FILENAME ]; then
	if [ -e "./${MANIFEST_ENVIRONMENT_VARIABLES_FILENAME}" ] && [ -e "./${MANIFEST_TEMPLATE_NAME}" ]; then
	
		# Create or replace .env file for generating manifest file and copy content from environment file from user to .env file
        # We are copying the content to .env file as it's required by iotedgedev service
		
		if [ "$CREATE_AZURE_MONITOR" == "true" ]; then
			echo "$(timestamp) [INFO] Updating Azure Monitor variables in $MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
			# Update Azure Monitor Values in env.template file
			sed -i "s/^\(TELEGRF_AZURE_TENANT_ID\s*=\s*\).*\$/\1$TELEGRAF_AZURE_TENANT_ID/" "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
			sed -i "s/^\(TELEGRF_AZURE_CLIENT_ID\s*=\s*\).*\$/\1$TELEGRAF_AZURE_CLIENT_ID/" "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
			sed -i "s/^\(TELEGRF_AZURE_CLIENT_SECRET\s*=\s*\).*\$/\1$TELEGRAF_AZURE_CLIENT_SECRET/" "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
			echo "$(timestamp) [INFO] Completed Update of Azure Monitor variables in $MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
		fi
		
		echo "$(timestamp) [INFO] Copying variable values from $MANIFEST_ENVIRONMENT_VARIABLES_FILENAME to .env"
		echo -n "" > .env
		cat $MANIFEST_ENVIRONMENT_VARIABLES_FILENAME >> .env
		echo "$(timestamp) [INFO] Copied values to .env"
		
		echo "$(timestamp) [INFO] Generating manifest file from template file"
		# Generate manifest file
		iotedgedev genconfig --file $MANIFEST_TEMPLATE_NAME
		
		echo "$(timestamp) [INFO] Generated manifest file"
		
        #Construct file path of the manifest file by getting file name of template file without extensions and then appending .json as file extension to it
        #We are prepending ./config to the filename as iotedgedev service creates a config folder and adds the manifest file in that folder 
		PRE_GENERATED_MANIFEST_FILENAME="./config/${MANIFEST_TEMPLATE_NAME%%.*}.json"
	else 
		echo "$(timestamp) [ERROR] ${MANIFEST_ENVIRONMENT_VARIABLES_FILENAME} and ${MANIFEST_TEMPLATE_NAME} files must be present in current directory"
		exit 1
	fi
else
	# This step will run if a pre-generated manifest file is provided and Azure Monitor step is run
	# This step will update the values in manifest json file
	# The manifest file must be a valid json file
	if [ "$CREATE_AZURE_MONITOR" == "true" ]; then
		echo "$(timestamp) [INFO] Updating Azure Monitor variables in $PRE_GENERATED_MANIFEST_FILENAME"

		# Updating value for Tenant ID of Azure Monitor 
		jq --arg valueToBeUpdated "$TELEGRF_AZURE_TENANT_ID" '.modulesContent."$edgeAgent"."properties.desired".modules.telegraf.env.AZURE_TENANT_ID.value = $valueToBeUpdated' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME" > tmp.$$.json && mv tmp.$$.json "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"

		# Updating value for Client ID of Azure Monitor 
		jq --arg valueToBeUpdated "$TELEGRF_AZURE_CLIENT_ID" '.modulesContent."$edgeAgent"."properties.desired".modules.telegraf.env.AZURE_CLIENT_ID.value = $valueToBeUpdated' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME" > tmp.$$.json && mv tmp.$$.json "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
	
		# Updating value for Client Secret of Azure Monitor 
		jq --arg valueToBeUpdated "$TELEGRF_AZURE_CLIENT_SECRET" '.modulesContent."$edgeAgent"."properties.desired".modules.telegraf.env.AZURE_CLIENT_SECRET.value = $valueToBeUpdated' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME" > tmp.$$.json && mv tmp.$$.json "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"

		echo "$(timestamp) [INFO] Updated Azure Monitor variables in $PRE_GENERATED_MANIFEST_FILENAME"
	fi
fi

# This step deploys the configured deployment manifest to the edge device. After completed,
# the device will begin to pull edge modules and begin executing workloads (including sending
# messages to the cloud for further processing, visualization, etc).
echo "$(timestamp) [INFO] Deploying $PRE_GENERATED_MANIFEST_FILENAME manifest file to $DEVICE_NAME Edge device"
az iot edge deployment create --deployment-id "$DEPLOYMENT_NAME" --hub-name "$IOTHUB_NAME" --content "$PRE_GENERATED_MANIFEST_FILENAME" --target-condition "deviceId='$DEVICE_NAME'"
echo "$(timestamp) [INFO] Deployed manifest file to IoT Hub. Your modules are being deployed to your device now. This may take some time."
