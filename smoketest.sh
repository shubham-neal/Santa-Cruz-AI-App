#!/bin/bash

#List of checks done by script:
#1. IoT Edge Service is installed/Running or not on Edge machine 
#2. Resource Group present or not
#3. IoT Hub present or not in Resource Group
#4. IoT Hub Device is present or not
#5. Default Route for built-in Event Hub endpoint present or not in IoT Hub
#6. IF data is routing to Data lake:
    #6.a  Storage account is present or not in the resource group
    #6.b  Container is present or not in Storage account
    #6.c  Custom Data Lake Storage endpoint is present or not in IoT Hub
    #6.d  Route to a Data Lake Storage account is present or not in IoT Hub
    #6.e  Data files are present or not in Storage account Container
#7. IF events are routing to Event Hub:
    #7.a  Event Hubs Namespace is present or not 
    #7.b  Event Hub is present or not in Event Hubs Namespace
    #7.c  custom Event Hubs endpoint is present or not in IoT Hub
    #7.d  Route to an Event Hub is present or not in IoT Hub
#8. Deployment of manifest file is successfully applied to the edge device or not  

#List of checks, currently we are not performing:
#1. IoT Edge Device Runtime Status on IoT Hub whether it is 200-OK OR Other than this.
#2. Events/Messages are coming into Event Hub successfully or not.


#This script will check for the deployed azure resources and configurations created by setup.sh (automated deployment of IoT Edge Device)
#and will throw error if any resource is missing or not configured as required:

# Stop execution on failure of a test:
# The script will exit with failure code 1 after one test failure. This is done to handle the the following scenario:
# The variables passed to the setup script are already present in azure. The setup script generates a unique name
# by appending a random number and one resource creation step succeeds but the subsequent steps fail. +
# If we allow the subsequent checks after one failure in smoketest script, they may be flagged as Passed incorrectly
set -e

# Set red color for Failure messages
FAILURE=$(tput setaf 1)
# Reset text color
RESET_COLOR=$(tput sgr0)

# Read variable values from variables.template file in current directory
source variables.template

#Log into azure either in a interactive way or non-interactive way based on a "USE_INTERACTIVE_LOGIN_FOR_AZURE" variable value
if [ "$USE_INTERACTIVE_LOGIN_FOR_AZURE" == "true" ]; then
    echo "[INFO] Attempting Login with User Authentication"

    az login --tenant "$TENANT_ID"
    
    echo "[INFO] Login Successful"

else
    echo "[INFO] Attempting Login with Service Principal Account"

    # Using service principal as it will not require user interaction
    az login --service-principal --username "$SP_APP_ID" --password "$SP_APP_PWD" --tenant "$TENANT_ID"

    echo "[INFO] Login Successful"
fi

echo "[INFO] Setting current subscription to $SUBSCRIPTION_ID"

az account set --subscription "$SUBSCRIPTION_ID"

echo "[INFO] Set current subscription to $SUBSCRIPTION_ID"


# Check for Resource Group, if it exists with the same name provided in variable template then pass the check else throw error
if [ "$(az group exists -n "$RESOURCE_GROUP")" = false ]; then
    echo "${FAILURE}Failed: Resource Group \"$RESOURCE_GROUP\" is not present ${RESET_COLOR}"
    exit 1

else
    echo "Passed: Resource Group \"$RESOURCE_GROUP\" is present"
fi

#Check for IoT Hub, if it exists with the same name as in variable template then pass the test else throw error
if [ -z "$(az iot hub list --query "[?name=='$IOTHUB_NAME'].{Name:name}" -o tsv)" ]; then
    echo "${FAILURE}Failed: IoT Hub \"$IOTHUB_NAME\" is not present ${RESET_COLOR}"
    exit 1

else
    echo "Passed: IoT Hub \"$IOTHUB_NAME\" is present"
fi

#Retrieve IoT Edge device name to check whether it has been registered on IoT Hub or not
DEVICE=$(az iot hub device-identity list --hub-name "$IOTHUB_NAME" --query "[?deviceId=='$DEVICE_NAME'].deviceId" -o tsv)

#Check for IoT Edge Device identity on IoT Hub, if it exists with the same name as in variable template then pass the test else throw error
if [ -z "$DEVICE" ]; then
    echo "${FAILURE}Failed: Device \"$DEVICE_NAME\" is not present in IoT Hub \"$IOTHUB_NAME\" ${RESET_COLOR}"
    exit 1

else
    echo "Passed: Device \"$DEVICE_NAME\" is present in IoT Hub \"$IOTHUB_NAME\""
fi

#Check for Default Route for built-in Event Hub endpoint
EXISTING_DEFAULT_ROUTE=$(az iot hub route list --hub-name "$IOTHUB_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='defaultroute'].name" --output tsv)
if [ -z "$EXISTING_DEFAULT_ROUTE" ]; then
    echo "${FAILURE}Failed: Default Route for built-in Event Hub endpoint is not present in IoT Hub \"$IOTHUB_NAME\" ${RESET_COLOR}"
    exit 1

else
    echo "Passed: Default Route for built-in Event Hub endpoint is present in IoT Hub \"$IOTHUB_NAME\""
fi

# Perform the ADLS checks only if PUSH_RESULTS_TO_ADLS is set to true
if [ "$PUSH_RESULTS_TO_ADLS" == "true" ]; then

    #Retrieve the name of Storage account to check if it exists
    STORAGE_ACCOUNT=$(az storage account list -g "$RESOURCE_GROUP" --query "[?name=='$STORAGE_ACCOUNT_NAME'].name" -o tsv)

    #Check for Storage account, if it exists with same name as in variable template then pass the test else throw error
    if [ -z "$STORAGE_ACCOUNT" ]; then
        echo "${FAILURE}Failed: Storage account \"$STORAGE_ACCOUNT_NAME\" is not present ${RESET_COLOR}"
        exit 1

    else
        echo "Passed: Storage account \"$STORAGE_ACCOUNT_NAME\" is present"
    fi

    #Retrieve account key to check for container existence
    STORAGE_ACCOUNT_KEY=$(az storage account keys list --resource-group "$RESOURCE_GROUP" --account-name "$STORAGE_ACCOUNT_NAME" --query "[0].value" | tr -d '"')

    #Retrieve status of container existence
    CONTAINER=$(az storage container exists --name "$BLOBCONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" -o tsv)

    #check for Container, if it exists with same name as in variable template pass the test else throw error
    if [ "$CONTAINER" == "True" ]; then
        echo "Passed: Container \"$BLOBCONTAINER_NAME\" is present in \"$STORAGE_ACCOUNT_NAME\" Storage account"

    else
        echo "${FAILURE}Failed: Container \"$BLOBCONTAINER_NAME\" is not present in \"$STORAGE_ACCOUNT_NAME\" Storage account ${RESET_COLOR}"
        exit 1
    fi

    #check for Data Lake Storage endpoint in IoT Hub, if it exists with the same name as in variable template pass the test else throw error
    if [ -z "$(az iot hub routing-endpoint list -g "$RESOURCE_GROUP" --hub-name "$IOTHUB_NAME" --endpoint-type azurestoragecontainer --query "[?name=='$ADLS_ENDPOINT_NAME'].name" -o tsv)" ]; then
        echo " ${FAILURE}Failed: Data Lake Storage endpoint \"$ADLS_ENDPOINT_NAME\" is not present in IoT Hub \"$IOTHUB_NAME\" ${RESET_COLOR}"
        exit 1

    else
        echo "Passed: Data Lake Storage endpoint \"$ADLS_ENDPOINT_NAME\" is present in IoT Hub \"$IOTHUB_NAME\""
    fi

    #Check for Route to a Data Lake Storage account in IoT Hub, if it exists then pass the test else throw error
    if [ -n "$(az iot hub route list -g "$RESOURCE_GROUP" --hub-name "$IOTHUB_NAME" --query "[?name=='$IOTHUB_ADLS_ROUTENAME'].name" -o tsv)" ]; then
        echo "Passed: Route to a Data Lake Storage account \"$IOTHUB_ADLS_ROUTENAME\" is present in IoT Hub \"$IOTHUB_NAME\" "

    else
        echo "${FAILURE}Failed: Route to a Data Lake Storage account \"$IOTHUB_ADLS_ROUTENAME\" is not present in IoT Hub \"$IOTHUB_NAME\" ${RESET_COLOR}"
        exit 1
    fi

    #Retrieve the file names and last modified date for files in data lake container
    CONTAINER_DATA=$(az storage fs file list -f "$BLOBCONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" --query "[*].{name:name,lastModified:lastModified}" -o table)

    #Check for data in data lake, if any files exist in container after setup pass the test else throw error
    if [ -n "$CONTAINER_DATA" ]; then
        echo "Passed: Data is present in the container \"$BLOBCONTAINER_NAME\" of \"$STORAGE_ACCOUNT_NAME\" Storage account"
    else
        echo "${FAILURE}Failed: Data is not present in the container \"$BLOBCONTAINER_NAME\" of \"$STORAGE_ACCOUNT_NAME\" Storage account ${RESET_COLOR} "
        exit 1
    fi
fi

# Perform the ADLS checks only if PUSH_RESULTS_TO_EVENT_HUB is set to true
if [ "$PUSH_RESULTS_TO_EVENT_HUB" == "true" ]; then

    #Retrieve the details of Event Hubs Namespace
    NAMESPACE=$(az eventhubs namespace list --resource-group "$RESOURCE_GROUP" --query "[?name=='$EVENTHUB_NAMESPACE'].name" -o tsv)

    #Check for Event Hubs Namespace, if it exists with same name as in variable template pass the test else throw error
    if [ -n "$NAMESPACE" ]; then
        echo "Passed: Event Hubs Namespace \"$EVENTHUB_NAMESPACE\" is present"

    else
        echo "${FAILURE}Failed: Event Hubs Namespace \"$EVENTHUB_NAMESPACE\" is not present ${RESET_COLOR}"
        exit 1
    fi

    #Check for Event Hub in Event Hubs Namespace, if it exists with same name as in variable template pass the test else throw error
    if [ "$(az eventhubs eventhub show --resource-group "$RESOURCE_GROUP" --namespace-name "$EVENTHUB_NAMESPACE" --name "$EVENTHUB_NAME" --query "name" -o tsv)" == "$EVENTHUB_NAME" ]; then
        echo "Passed: Event Hub \"$EVENTHUB_NAME\" is present in Event Hubs Namespace \"$EVENTHUB_NAMESPACE\" "

    else
        echo "${FAILURE}Failed: Event Hub \"$EVENTHUB_NAME\" is not present in Event Hubs Namespace \"$EVENTHUB_NAMESPACE\" ${RESET_COLOR}"
        exit 1
    fi

    #Check for custom Event Hubs endpoint in IoT Hub, if it exists with same name as in variable template pass the testelse throw error
    if [ -n "$(az iot hub routing-endpoint list -g "$RESOURCE_GROUP" --hub-name "$IOTHUB_NAME" --endpoint-type eventhub --query "[?name=='$EVENTHUB_ENDPOINT_NAME'].name" -o tsv)" ]; then
        echo "Passed: Event Hubs endpoint \"$EVENTHUB_ENDPOINT_NAME\" is present in IoT Hub \"$IOTHUB_NAME\""

    else
        echo "${FAILURE}Failed: Event Hubs endpoint \"$EVENTHUB_ENDPOINT_NAME\" is not present in IoT Hub \"$IOTHUB_NAME\" ${RESET_COLOR}"
        exit 1
    fi

    #Check for Route to an Event Hub in IoT Hub, if it exists then pass the test else throw error
    if [ -n "$(az iot hub route list -g "$RESOURCE_GROUP" --hub-name "$IOTHUB_NAME" --query "[?name=='$EVENTHUB_ROUTENAME'].name" -o tsv)" ]; then
        echo "Passed: Route to an Event Hub \"$EVENTHUB_ROUTENAME\" is present in IoT Hub \"$IOTHUB_NAME\" "

    else
        echo "${FAILURE}Failed: Route to an Event Hub \"$EVENTHUB_ROUTENAME\" is not present in IoT Hub \"$IOTHUB_NAME\" ${RESET_COLOR}"
        exit 1
    fi
fi

#Retrieve the deployment details for applied deployments on IoT Hub
DEPLOYMENT_STATUS=$(az iot edge deployment show-metric -m appliedCount --config-id "$DEPLOYMENT_NAME" --hub-name "$IOTHUB_NAME" --metric-type system --query "result" -o tsv)

#Check if the current applied deployment is the one variables.template file, if it is pass the test else throw error
if [ "$DEPLOYMENT_STATUS" == "$DEVICE_NAME" ]; then
    echo "Passed: Deployment is Applied on Edge Device \"$DEVICE_NAME\" "

else
    echo "${FAILURE}Failed: Deployment \"$DEPLOYMENT_NAME\" is not Applied on Edge Device \"$DEVICE_NAME\" ${RESET_COLOR} "
    exit 1
fi


#Check the status of IoT Edge Service
# If the value of IS_THE_SCRIPT_RUNNING_FROM_EDGE_DEVICE is true, run the check on current device else use sshpass to run the check on a remote device
if [ "$IS_THE_SCRIPT_RUNNING_FROM_EDGE_DEVICE" == "true" ]; then
    #Check if status of iotedge service is running on Edge Device
    if sudo systemctl --type=service --state=running | grep -q -i "iotedge" ; then
        echo "Passed: IoT Edge Service is installed and running on Edge Device"

    else
        #Check if iotedge service is installed on Edge Device
        if sudo systemctl --type=service | grep -q "iotedge" ; then
            echo "${FAILURE}Failed: IoT Edge Service is installed but not running on Edge Device ${RESET_COLOR}"
            exit 1
            
        else
            echo "${FAILURE}Failed: IoT Edge Service is not installed on Edge Device ${RESET_COLOR}"
            exit 1
        fi
    fi

else
    RUNNING_STATUS_COMMAND="sudo systemctl --type=service --state=running | grep -i \"iotedge\" "
    INSTALLATION_STATUS_COMMAND="sudo systemctl --type=service | grep -i \"iotedge\" "

    #Check if status of iotedge service is running on Edge Device
    RUNNING_STATUS=$(sshpass -p "$EDGE_DEVICE_PASSWORD" ssh "$EDGE_DEVICE_USERNAME"@"$EDGE_DEVICE_IP" -o StrictHostKeyChecking=no "$RUNNING_STATUS_COMMAND")

    #Check if iotedge service is installed on Edge Device
    INSTALLATION_STATUS=$(sshpass -p "$EDGE_DEVICE_PASSWORD" ssh "$EDGE_DEVICE_USERNAME"@"$EDGE_DEVICE_IP" -o StrictHostKeyChecking=no "$INSTALLATION_STATUS_COMMAND")

    if [ -n "$RUNNING_STATUS" ]; then
        echo "Passed: IoT Edge Service is installed and running on Edge Device"

    else
        if [ -n "$INSTALLATION_STATUS" ]; then
            echo "${FAILURE}Failed: IoT Edge Service is installed but not running on Edge Device ${RESET_COLOR}"
            exit 1
            
        else
            echo "${FAILURE}Failed: IoT Edge Service is not installed on Edge Device ${RESET_COLOR}"
            exit 1
        fi
    fi
fi
