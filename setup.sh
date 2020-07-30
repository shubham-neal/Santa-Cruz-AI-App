#!/usr/bin/env bash

# Stop execution on any error from azure cli
set -e

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

##############################################################################
# Check existence and value of a variable
# The function checks if the provided variable exists and it is a non-empty value.
# If it doesn't exists it adds the variable name to ARRAY_NOT_DEFINED_VARIABLES array and if it exists but doesn't have value, variable name is added ARRAY_VARIABLES_WITHOUT_VALUES array.
# In case a 3rd positional argument is provided, the function will output 1 if given variable exists and has a non-empty value, else it will output 0.
# Globals:
#	ARRAY_VARIABLES_WITHOUT_VALUES
#	ARRAY_NOT_DEFINED_VARIABLES
#	ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY
# Arguments:
#	Name of the variable
#	Value of the variable
#	Whether to print the result (Optional)
# Outputs:
#	The function writes the results if a 3rd positional parameter is passed in arguments
##############################################################################
checkValue() {
    # The first value passed to the function is the name of the variable
    # Check it's existence in file using -v
    if [ -v "$1" ]; then
        # The second value passed to the function is the actual value of the variable
        # Check if it is empty using -z
        if [ -z "$2" ]; then
            # If the value is empty, add the variable name ($1) to ARRAY_VARIABLES_WITHOUT_VALUES array and set ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY to false
            ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY="false"
            ARRAY_VARIABLES_WITHOUT_VALUES+=("$1")
            # The third value is passed to the function when the caller expects the result
            # The function returns 0 as the value of the variable is empty
            if [ ! -z "$3" ]; then
                echo 0
            fi
        else
            # The third value is passed to the function when the caller expects the result
            # When the variable exists and it's value is not empty, function returns 1
            if [ ! -z "$3" ]; then
                echo 1
            fi
        fi
    else
        # If the variable is not defined, add the variable name to ARRAY_NOT_DEFINED_VARIABLES array and set ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY to false
        ARRAY_NOT_DEFINED_VARIABLES+=("$1")
        ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY="false"
        # The third value is passed to the function when the caller expects the result
        # The function returns 0 as the variable is not defined
        if [ ! -z "$3" ]; then
            echo 0
        fi
    fi
}

printf "\n%60s\n" " " | tr ' ' '-'
echo "Checking if the required variables are configured"
printf "%60s\n" " " | tr ' ' '-'

SETUP_VARIABLES_TEMPLATE_FILENAME="variables.template"

if [ ! -f "$SETUP_VARIABLES_TEMPLATE_FILENAME" ]; then
    echo "$(error) \"$SETUP_VARIABLES_TEMPLATE_FILENAME\" file is not present in current directory: \"$PWD\""
    exitWithError
fi


# The following comment is for ignoring the source file check for shellcheck, as it does not support variable source file names currently
# shellcheck source=variables.template
# Read variable values from SETUP_VARIABLES_TEMPLATE_FILENAME file in current directory
source "$SETUP_VARIABLES_TEMPLATE_FILENAME"

# Checking the existence and values of mandatory variables

# Setting default values for variable check stage
ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY="true"
ARRAY_VARIABLES_WITHOUT_VALUES=()
ARRAY_NOT_DEFINED_VARIABLES=()

# Pass the name of the variable and it's value to the checkValue function
checkValue "USE_INTERACTIVE_LOGIN_FOR_AZURE" "$USE_INTERACTIVE_LOGIN_FOR_AZURE"
checkValue "TENANT_ID" "$TENANT_ID"

checkValue "SUBSCRIPTION_ID" "$SUBSCRIPTION_ID"
checkValue "RESOURCE_GROUP" "$RESOURCE_GROUP"
checkValue "LOCATION" "$LOCATION"
checkValue "USE_EXISTING_RESOURCES" "$USE_EXISTING_RESOURCES"
checkValue "INSTALL_REQUIRED_PACKAGES" "$INSTALL_REQUIRED_PACKAGES"


checkValue "IOTHUB_NAME" "$IOTHUB_NAME"
checkValue "DEVICE_NAME" "$DEVICE_NAME"

checkValue "STORAGE_ACCOUNT_NAME" "$STORAGE_ACCOUNT_NAME"

#checkValue "CREATE_AZURE_MONITOR" "$CREATE_AZURE_MONITOR"

checkValue "EDGE_DEVICE_IP" "$EDGE_DEVICE_IP"
checkValue "EDGE_DEVICE_USERNAME" "$EDGE_DEVICE_USERNAME"
checkValue "EDGE_DEVICE_PASSWORD" "$EDGE_DEVICE_PASSWORD"
checkValue "DETECTOR_MODULE_RUNTIME" "$DETECTOR_MODULE_RUNTIME"
checkValue "EDGE_DEVICE_ARCHITECTURE" "$EDGE_DEVICE_ARCHITECTURE"

checkValue "MANIFEST_TEMPLATE_NAME" "$MANIFEST_TEMPLATE_NAME"
checkValue "MANIFEST_ENVIRONMENT_VARIABLES_FILENAME" "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
checkValue "DEPLOYMENT_NAME" "$DEPLOYMENT_NAME"

# Check the existence and value of the optional variables depending on the value of mandatory variables
# Pass a third variable so checkValue function will return whether the variable is empty or not
IS_NOT_EMPTY=$(checkValue "CREATE_AZURE_MONITOR" "$CREATE_AZURE_MONITOR" "RETURN_VARIABLE_STATUS")
if [ "$IS_NOT_EMPTY" == "1" ] && [ "$CREATE_AZURE_MONITOR" == "true" ]; then
    checkValue "AZURE_MONITOR_SP_NAME" "$AZURE_MONITOR_SP_NAME"
fi

IS_NOT_EMPTY=$(checkValue "USE_INTERACTIVE_LOGIN_FOR_AZURE" "$USE_INTERACTIVE_LOGIN_FOR_AZURE" "RETURN_VARIABLE_STATUS")
if [ "$IS_NOT_EMPTY" == "1" ] && [ "$USE_INTERACTIVE_LOGIN_FOR_AZURE" == "true" ]; then
    checkValue "SP_APP_ID" "$SP_APP_ID"
    checkValue "SP_APP_PWD" "$SP_APP_PWD"
fi

# Check if all the variables are set up correctly
if [ "$ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY" == "false" ]; then
    # Check if there are any required variables which are not defined
    if [ "${#ARRAY_NOT_DEFINED_VARIABLES[@]}" -gt 0 ]; then
        echo "$(error) The following variables must be defined in the variables file"
        printf '%s\n' "${ARRAY_NOT_DEFINED_VARIABLES[@]}"
    fi
    # Check if there are any required variables which are empty
    if [ "${#ARRAY_VARIABLES_WITHOUT_VALUES[@]}" -gt 0 ]; then
        echo "$(error) The following variables must have a value in the variables file"
        printf '%s\n' "${ARRAY_VARIABLES_WITHOUT_VALUES[@]}"
    fi
    exitWithError
fi

echo "$(info) The required variables are defined and have a non-empty value"

if [ ! -f "${MANIFEST_ENVIRONMENT_VARIABLES_FILENAME}" ] || [ ! -f "${MANIFEST_TEMPLATE_NAME}" ]; then
    echo "$(error) \"$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME\" and \"$MANIFEST_TEMPLATE_NAME\" files must be present in current directory: \"$PWD\""
    exitWithError
fi

# Check value of POWERSHELL_DISTRIBUTION_CHANNEL. This variable is present in Azure Cloud Shell environment. 
# There are different installation steps for Cloud Shell as it does not allow root access to the script
if [ "$POWERSHELL_DISTRIBUTION_CHANNEL" == "CloudShell" ]; then

    if [ -z "$(command -v sshpass)" ]; then

    echo "$(info) Installing sshpass"
    # Download the sshpass package to current machine
    apt-get download sshpass
    # Install sshpass package in current working directory
    dpkg -x sshpass*.deb ~
    # Add the executable directory path in PATH 
    echo "PATH=~/usr/bin:$PATH" >> ~/.bashrc
    PATH=~/usr/bin:$PATH
    # Remove the package file
    rm sshpass*.deb

        if [ -z "$(command -v sshpass)" ]; then
            echo "$(error) sshpass is not installed"
            exitWithError
        else
            echo "$(info) Installed sshpass"
        fi

    fi
    
    if [ -z "$(command -v iotedgedev)" ]; then
    echo "$(info) Installing iotedgedev"

    # Install iotedgedev package
    pip install iotedgedev==2.0.2
    # Add iotedgedev path to PATH variable
    echo "PATH=~/.local/bin:$PATH" >> ~/.bashrc    
    PATH=~/.local/bin:$PATH

        if [ -z "$(command -v iotedgedev)" ]; then
            echo "$(error) iotedgedev is not installed"
            exitWithError
        else
            echo "$(info) Installed iotedgedev"
        fi
    fi

    if [[ $(az extension list --query "[?name=='azure-cli-iot-ext'].name" --output tsv | wc -c) -eq 0 ]]; then
            echo "$(info) Installing azure-cli-iot-ext extension"
            az extension add --name azure-cli-iot-ext
    fi

    # jq, pip and rsync packages are pre-installed in the cloud shell 

elif [ "$INSTALL_REQUIRED_PACKAGES" == "true" ]; then

    if [ ! -z "$(command -v apt)" ]; then
        PACKAGE_MANAGER="apt"
    elif [ ! -z "$(command -v dnf)" ]; then
        PACKAGE_MANAGER="dnf"
    elif [ ! -z "$(command -v yum)" ]; then
        PACKAGE_MANAGER="dnf"
    elif [ ! -z "$(command -v zypper)" ]; then
        PACKAGE_MANAGER="zypper"
    fi

    if [ -z "$PACKAGE_MANAGER" ]; then
        echo "[WARNING] The current machine does not have any of the following package managers installed: apt, yum, dnf, zypper."
        echo "[WARNING] Package Installation step is being skipped. Please install the required packages manually"
    else

        echo "$(info) Installing required packages"

        echo "$(info) Installing sshpass"
        sudo "$PACKAGE_MANAGER" install -y sshpass

        echo "$(info) Installing jq"
        sudo "$PACKAGE_MANAGER" install -y jq

        echo "$(info) Installing pip"
        sudo "$PACKAGE_MANAGER" install -y python-pip

        echo "$(info) Installing iotedgedev"
        sudo pip install iotedgedev==2.0.2

        echo "$(info) Installing rsync"
        sudo "$PACKAGE_MANAGER" install -y rsync

        if [[ $(az extension list --query "[?name=='azure-cli-iot-ext'].name" --output tsv | wc -c) -eq 0 ]]; then
            echo "$(info) Installing azure-cli-iot-ext extension"
            az extension add --name azure-cli-iot-ext
        fi

        echo "$(info) Package Installation step is complete"
    fi
fi

# Log into Azure
printf "\n%60s\n" " " | tr ' ' '-'
echo "Logging into Azure Subscription"
printf "%60s\n" " " | tr ' ' '-'

# This step checks the value for USE_INTERACTIVE_LOGIN_FOR_AZURE.
# If the value is true, the script will allow
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

# Set Azure Subscription
printf "\n%60s\n" " " | tr ' ' '-'
echo "Connecting to Azure Subscription"
printf "%60s\n" " " | tr ' ' '-'

echo "$(info) Setting current subscription to \"$SUBSCRIPTION_ID\""
az account set --subscription "$SUBSCRIPTION_ID"
echo "$(info) Successfully set subscription to \"$SUBSCRIPTION_ID\""

printf "\n%60s\n" " " | tr ' ' '-'
echo Configuring Resource Group
printf "%60s\n" " " | tr ' ' '-'

# Create a new resource group if it does not exist already.
# If it already exists then check value for USE_EXISTING_RESOURCES
# and based on that either throw error or use the existing RG
if [ "$(az group exists --name "$RESOURCE_GROUP")" == false ]; then
    echo "$(info) Creating a new Resource Group: \"$RESOURCE_GROUP\""
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output "none"
    echo "$(info) Successfully created resource group \"$RESOURCE_GROUP\""
else
    if [ "$USE_EXISTING_RESOURCES" == "true" ]; then
        echo "$(info) Using Existing Resource Group: \"$RESOURCE_GROUP\""
    else
        echo "$(error) Resource Group \"$RESOURCE_GROUP\" already exists"
        exitWithError
    fi
fi

printf "\n%60s\n" " " | tr ' ' '-'
echo Configuring IoT Hub
printf "%60s\n" " " | tr ' ' '-'

# Generating a random number. This will be used in case a user provided name is not unique.
RANDOM_SUFFIX="${RANDOM:0:3}"

# We are checking if the IoTHub already exists by querying the list of IoT Hubs in current subscription.
# It will return a blank array if it does not exist. Create a new IoT Hub if it does not exist,
# if it already exists then check value for USE_EXISTING_RESOURCES. If it is set to yes, use existing IoT Hub
# else create a new IoT Hub by appending a random number to the user provided name
EXISTING_IOTHUB=$(az iot hub list --query "[?name=='$IOTHUB_NAME'].{Name:name}" --output tsv)

if [ -z "$EXISTING_IOTHUB" ]; then
    echo "$(info) Creating a new IoT Hub \"$IOTHUB_NAME\""
    az iot hub create --name "$IOTHUB_NAME" --sku S1 --resource-group "$RESOURCE_GROUP" --output "none"
    echo "$(info) Created a new IoT hub \"$IOTHUB_NAME\""
else
    # Check if IoT Hub exists in current resource group. If it doesn't exist in current resource group. Create a new one based on value of USE_EXISTING_RESOURCES
    EXISTING_IOTHUB=$(az iot hub list --resource-group "$RESOURCE_GROUP" --query "[?name=='$IOTHUB_NAME'].{Name:name}" --output tsv)
    if [ "$USE_EXISTING_RESOURCES" == "true" ] && [ ! -z "$EXISTING_IOTHUB" ]; then
        echo "$(info) Using existing IoT Hub \"$IOTHUB_NAME\""
    else
        if [ "$USE_EXISTING_RESOURCES" == "true" ]; then
            echo "$(info) \"$IOTHUB_NAME\" already exists in current subscription but it does not exist in resource group \"$RESOURCE_GROUP\""
        else
            echo "$(info) \"$IOTHUB_NAME\" already exists"
        fi
        echo "$(info) Appending a random number \"$RANDOM_SUFFIX\" to \"$IOTHUB_NAME\""
        IOTHUB_NAME=${IOTHUB_NAME}${RANDOM_SUFFIX}
        # Writing the updated value back to variables file
        sed -i 's#^\(IOTHUB_NAME[ ]*=\).*#\1\"'"$IOTHUB_NAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"

        echo "$(info) Creating a new IoT Hub \"$IOTHUB_NAME\""
        az iot hub create --name "$IOTHUB_NAME" --sku S1 --resource-group "$RESOURCE_GROUP" --output "none"
        echo "$(info) Created a new IoT hub \"$IOTHUB_NAME\""
    fi
fi

DEFAULT_ROUTE_ROUTING_CONDITION="\$twin.moduleId = 'tracker' OR \$twin.moduleId = 'camerastream'"

# Adding default route in IoT hub. This is used to retrieve messages from IoT Hub
# as they are generated.
EXISTING_DEFAULT_ROUTE=$(az iot hub route list --hub-name "$IOTHUB_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='defaultroute'].name" --output tsv)
if [ -z "$EXISTING_DEFAULT_ROUTE" ]; then
    echo "$(info) Creating default IoT Hub route"
    az iot hub route create --name "defaultroute" --hub-name "$IOTHUB_NAME" --source devicemessages --resource-group "$RESOURCE_GROUP" --endpoint-name "events" --enabled --condition "$DEFAULT_ROUTE_ROUTING_CONDITION" --output "none"
else
    echo "$(info) Updating existing default IoT Hub route"
    az iot hub route update --name "defaultroute" --hub-name "$IOTHUB_NAME" --source devicemessages --resource-group "$RESOURCE_GROUP" --endpoint-name "events" --enabled --condition "$DEFAULT_ROUTE_ROUTING_CONDITION" --output "none"
fi


# Check if the user provided name is valid and available in Azure
NAME_CHECK_JSON=$(az storage account check-name --name "$STORAGE_ACCOUNT_NAME")
IS_NAME_AVAILABLE=$(echo "$NAME_CHECK_JSON" | jq -r '.nameAvailable')

if [ "$IS_NAME_AVAILABLE" == "true" ]; then
    echo "$(info) Creating a storage account \"$STORAGE_ACCOUNT_NAME\""
    az storage account create --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" --sku Standard_RAGRS --kind StorageV2 --enable-hierarchical-namespace true --output "none"
    echo "$(info) Created storage account \"$STORAGE_ACCOUNT_NAME\""
else
    # Check the unavailability reason. If the user provided name is invalid, throw error with message received from Azure
    UNAVAILABILITY_REASON=$(echo "$NAME_CHECK_JSON" | jq -r '.reason')
    if [ "$UNAVAILABILITY_REASON" == "AccountNameInvalid" ]; then
        echo "$(error) UNAVAILABILITY_REASON: $(echo "$NAME_CHECK_JSON" | jq '.message')"
        exitWithError
    else
        # Check if the Storage Account exists in current resource group. This handles scenario, where a Storage Account exists but not in current resource group.
        # If it doesn't exists in current Resource Group or USE_EXISTING_RESOURCES is not set to true, create a new storage account by appending a random number to user provided name
        EXISTENCE_IN_RG=$(az storage account list --subscription "$SUBSCRIPTION_ID" --resource-group "$RESOURCE_GROUP" --query "[?name=='$STORAGE_ACCOUNT_NAME'].{Name:name}" --output tsv)
        if [ "$USE_EXISTING_RESOURCES" == "true" ] && [ ! -z "$EXISTENCE_IN_RG" ]; then
            echo "$(info) Using existing storage account \"$STORAGE_ACCOUNT_NAME\""
        else
            echo "$(info) Storage account \"$STORAGE_ACCOUNT_NAME\" already exists"
            echo "$(info) Appending a random number \"$RANDOM_SUFFIX\" to storage account name \"$STORAGE_ACCOUNT_NAME\""
            STORAGE_ACCOUNT_NAME=${STORAGE_ACCOUNT_NAME}${RANDOM_SUFFIX}
            # Writing the updated value back to variables file
            sed -i 's#^\(STORAGE_ACCOUNT_NAME[ ]*=\).*#\1\"'"$STORAGE_ACCOUNT_NAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
            echo "$(info) Creating storage account \"$STORAGE_ACCOUNT_NAME\""
            az storage account create --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" --sku Standard_RAGRS --kind StorageV2 --enable-hierarchical-namespace true --output "none"
            echo "$(info) Created storage account \"$STORAGE_ACCOUNT_NAME\""
        fi
    fi
fi

# Get storage account key
STORAGE_ACCOUNT_KEY=$(az storage account keys list --resource-group "$RESOURCE_GROUP" --account-name "$STORAGE_ACCOUNT_NAME" --query "[0].value" | tr -d '"')

DETECTOR_OUTPUT_CONTAINER_NAME="detectoroutput"
# Check if the storage container exists, use it if it already exists else create a new one
EXISTING_STORAGE_CONTAINER=$(az storage container list --account-name "$STORAGE_ACCOUNT_NAME" --auth-mode "login" --query "[?name=='$DETECTOR_OUTPUT_CONTAINER_NAME'].{Name:name}" --output tsv)
if [ -z "$EXISTING_STORAGE_CONTAINER" ]; then
    echo "$(info) Creating storage container \"$DETECTOR_OUTPUT_CONTAINER_NAME\""
    az storage container create --name "$DETECTOR_OUTPUT_CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" --public-access off --output "none"
    echo "$(info) Created storage container \"$DETECTOR_OUTPUT_CONTAINER_NAME\""
else
    echo "$(info) Using existing container \"$DETECTOR_OUTPUT_CONTAINER_NAME\" in storage account \"$STORAGE_ACCOUNT_NAME\""
fi

IMAGES_CONTAINER_NAME="still-images"
# Check if the storage container exists, use it if it already exists else create a new one
EXISTING_STORAGE_CONTAINER=$(az storage container list --account-name "$STORAGE_ACCOUNT_NAME" --auth-mode "login" --query "[?name=='$IMAGES_CONTAINER_NAME'].{Name:name}" --output tsv)
if [ -z "$EXISTING_STORAGE_CONTAINER" ]; then
    echo "$(info) Creating storage container \"$IMAGES_CONTAINER_NAME\""
    az storage container create --name "$IMAGES_CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" --public-access off --output "none"
    echo "$(info) Created storage container \"$IMAGES_CONTAINER_NAME\""
else
    echo "$(info) Using existing container \"$IMAGES_CONTAINER_NAME\" in storage account \"$STORAGE_ACCOUNT_NAME\""
fi

# Retrieve connection string for storage account
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -g "$RESOURCE_GROUP" -n "$STORAGE_ACCOUNT_NAME" --query connectionString -o tsv)

SAS_EXPIRY_DATE=$(date -u -d "1 year" '+%Y-%m-%dT%H:%MZ')
STORAGE_BLOB_SHARED_ACCESS_SIGNATURE=$(az storage account generate-sas --account-name "$STORAGE_ACCOUNT_NAME" --expiry "$SAS_EXPIRY_DATE" --permissions "rwacl" --resource-types "sco" --services "b" --connection-string "$STORAGE_CONNECTION_STRING" --output tsv)
STORAGE_CONNECTION_STRING_WITH_SAS="BlobEndpoint=https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/;SharedAccessSignature=${STORAGE_BLOB_SHARED_ACCESS_SIGNATURE}"

ADLS_ENDPOINT_NAME="adls-endpoint"

# Check if a azure storage endpoint with given name already exists in IoT Hub. If it doesn't exist create a new one.
# If it exists, check if all the properties are same as provided to current script. If the properties are same, use existing endpoint else create a new one
EXISTING_ENDPOINT=$(az iot hub routing-endpoint list --hub-name "$IOTHUB_NAME" --resource-group "$RESOURCE_GROUP" --query "*[?name=='$ADLS_ENDPOINT_NAME'].name" --output tsv)
if [ -z "$EXISTING_ENDPOINT" ]; then
    echo "$(info) Creating a custom endpoint $ADLS_ENDPOINT_NAME in IoT Hub for ADLS"
    # Create a custom-endpoint for storage account on IoT Hub
    az iot hub routing-endpoint create --resource-group "$RESOURCE_GROUP" --hub-name "$IOTHUB_NAME" --endpoint-name "$ADLS_ENDPOINT_NAME" --endpoint-type azurestoragecontainer --endpoint-resource-group "$RESOURCE_GROUP" --endpoint-subscription-id "$SUBSCRIPTION_ID" --connection-string "$STORAGE_CONNECTION_STRING" --container-name "$DETECTOR_OUTPUT_CONTAINER_NAME" --batch-frequency 60 --chunk-size 100 --encoding json --ff "{iothub}/{partition}/{YYYY}/{MM}/{DD}/{HH}/{mm}" --output "none"
else

    # check details of current endpoint
    EXISTING_ENDPOINT=$(az iot hub routing-endpoint list --resource-group "$RESOURCE_GROUP" --hub-name "$IOTHUB_NAME" --query "storageContainers[?name=='$ADLS_ENDPOINT_NAME']" --output json)

    IS_NEW_ENDPOINT_SAME_AS_EXISTING="false"
    if [ ! -z "$EXISTING_ENDPOINT" ]; then
        EXISTING_SA_RG=$(echo "$EXISTING_ENDPOINT" | jq -r '.[0].resourceGroup')
        EXISTING_SA_SUBSCRIPTION=$(echo "$EXISTING_ENDPOINT" | jq -r '.[0].subscriptionId')
        # Retrieve storage account from connection string using cut
        EXISTING_SA_NAME=$(echo "$EXISTING_ENDPOINT" | jq -r '.[0].connectionString' | cut -d';' -f 3 | cut -d'=' -f 2)
        EXISTING_SA_CONTAINER=$(echo "$EXISTING_ENDPOINT" | jq -r '.[0].containerName')

        if [ "$EXISTING_SA_RG" == "$RESOURCE_GROUP" ] && [ "$EXISTING_SA_SUBSCRIPTION" == "$SUBSCRIPTION_ID" ] && [ "$EXISTING_SA_NAME" == "$STORAGE_ACCOUNT_NAME" ] && [ "$EXISTING_SA_CONTAINER" == "$DETECTOR_OUTPUT_CONTAINER_NAME" ]; then
            IS_NEW_ENDPOINT_SAME_AS_EXISTING="true"
        fi
    fi
    if [ "$IS_NEW_ENDPOINT_SAME_AS_EXISTING" == "true" ]; then
        echo "$(info) Using existing endpoint \"$ADLS_ENDPOINT_NAME\""
    else
        echo "$(info) Custom endpoint \"$ADLS_ENDPOINT_NAME\" already exists in IoT Hub \"$IOTHUB_NAME\". It's configuration is different from the values provided to this script."
        echo "$(info) Appending a random number \"$RANDOM_SUFFIX\" to custom endpoint name \"$ADLS_ENDPOINT_NAME\""
        ADLS_ENDPOINT_NAME=${ADLS_ENDPOINT_NAME}${RANDOM_SUFFIX}

        # Writing the updated value back to variables file
        sed -i 's#^\(ADLS_ENDPOINT_NAME[ ]*=\).*#\1\"'"$ADLS_ENDPOINT_NAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
        echo "$(info) Creating a custom endpoint \"$ADLS_ENDPOINT_NAME\" in IoT Hub for ADLS"
        # Create a custom-endpoint for storage account on IoT Hub
        az iot hub routing-endpoint create --resource-group "$RESOURCE_GROUP" --hub-name "$IOTHUB_NAME" --endpoint-name "$ADLS_ENDPOINT_NAME" --endpoint-type azurestoragecontainer --endpoint-resource-group "$RESOURCE_GROUP" --endpoint-subscription-id "$SUBSCRIPTION_ID" --connection-string "$STORAGE_CONNECTION_STRING" --container-name "$DETECTOR_OUTPUT_CONTAINER_NAME" --batch-frequency 60 --chunk-size 100 --encoding json --ff "{iothub}/{partition}/{YYYY}/{MM}/{DD}/{HH}/{mm}" --output "none"
        echo "$(info) Created custom endpoint \"$ADLS_ENDPOINT_NAME\""
    fi
fi

IOTHUB_ADLS_ROUTENAME="adls-route"
ADLS_ROUTING_CONDITION="\$twin.moduleId = 'camerastream'"

# Check if a route exists with given name, update it if it already exists else create a new one
# Adding route to send messages to ADLS. This step creates an Azure Data Lake Storage account,
# and creates routing endpoints and routes in Iot Hub. Messages will spill into a data lake
# every one minute.
EXISTING_IOTHUB_ADLS_ROUTE=$(az iot hub route list --hub-name "$IOTHUB_NAME" --query "[?name=='$IOTHUB_ADLS_ROUTENAME'].{Name:name}" --output tsv)
if [ -z "$EXISTING_IOTHUB_ADLS_ROUTE" ]; then

    echo "$(info) Creating a route in IoT Hub for ADLS custom endpoint"
    # Create a route for storage endpoint on IoT Hub
    az iot hub route create --name "$IOTHUB_ADLS_ROUTENAME" --hub-name "$IOTHUB_NAME" --source devicemessages --resource-group "$RESOURCE_GROUP" --endpoint-name "$ADLS_ENDPOINT_NAME" --enabled --condition "$ADLS_ROUTING_CONDITION" --output "none"
    echo "$(info) Created route \"$IOTHUB_ADLS_ROUTENAME\" in IoT Hub \"$IOTHUB_NAME\""
else

    echo "$(info) Updating existing route \"$IOTHUB_ADLS_ROUTENAME\""
    az iot hub route update --name "$IOTHUB_ADLS_ROUTENAME" --hub-name "$IOTHUB_NAME" --source devicemessages --resource-group "$RESOURCE_GROUP" --endpoint-name "$ADLS_ENDPOINT_NAME" --enabled --condition "$ADLS_ROUTING_CONDITION" --output "none"
    echo "$(info) Updated existing route \"$IOTHUB_ADLS_ROUTENAME\""
fi


# This step creates a new edge device in the IoT Hub account or will use an existing edge device
# if the USE_EXISTING_RESOURCES configuration variable is set to true.
printf "\n%60s\n" " " | tr ' ' '-'
echo Configuring Edge Device in IoT Hub
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


# if [ "$CREATE_AZURE_MONITOR" == "true" ]; then
#     echo "$(info) Retrieve resource id for IoT Hub"
#     IOTHUB_RESOURCE_ID=$(az iot hub list --query "[?name=='$IOTHUB_NAME'].{resourceID:id}" --output tsv)

#     echo "$(info) Creating an Azure Monitor"
#     AZ_MONITOR_SP=$(az ad sp create-for-rbac --role="Monitoring Metrics Publisher" --name "$AZURE_MONITOR_SP_NAME" --scopes="$IOTHUB_RESOURCE_ID")
#     TELEGRAF_AZURE_TENANT_ID=$TENANT_ID
#     TELEGRAF_AZURE_CLIENT_ID=$(echo "$AZ_MONITOR_SP" | jq -r '.appId')
#     TELEGRAF_AZURE_CLIENT_SECRET=$(echo "$AZ_MONITOR_SP" | jq -r '.password')
#     echo "$(info) Azure Monitor creation is complete"
# fi

# The following steps retrieves the connection string for the edge device an uses it to onboard
# the device using sshpass. This step may fail if the edge device's network firewall
# does not allow ssh access. Please make sure the edge device is on the local area
# network and is accepting ssh requests.
echo "$(info) Retrieving connection string for device \"$DEVICE_NAME\" from Iot Hub \"$IOTHUB_NAME\" and updating the IoT Edge service in edge device with this connection string"
EDGE_DEVICE_CONNECTION_STRING=$(az iot hub device-identity show-connection-string --device-id "$DEVICE_NAME" --hub-name "$IOTHUB_NAME" --query "connectionString" -o tsv)

echo "$(info) Updating Config.yaml on edge device with the connection string from IoT Hub"
CONFIG_FILE_PATH="/etc/iotedge/config.yaml"
# Replace placeholder connection string with actual value for Edge device
# Using sshpass and ssh to update the value on Edge device
Command="sudo sed -i -e '/device_connection_string:/ s#\"[^\"][^\"]*\"#\"$EDGE_DEVICE_CONNECTION_STRING\"#' $CONFIG_FILE_PATH"
sshpass -p "$EDGE_DEVICE_PASSWORD" ssh "$EDGE_DEVICE_USERNAME"@"$EDGE_DEVICE_IP" -o StrictHostKeyChecking=no "$Command"
echo "$(info) Config.yaml update is complete"

echo "$(info) Restarting IoT Edge service"
# Restart the service on Edge device
sshpass -p "$EDGE_DEVICE_PASSWORD" ssh "$EDGE_DEVICE_USERNAME"@"$EDGE_DEVICE_IP" -o StrictHostKeyChecking=no "sudo systemctl restart iotedge"
echo "$(info) IoT Edge service restart is complete"


# This step uses the iotedgedev cli toolkit to inject defined environment variables into a predefined deployment manifest JSON
# file. Once an environment specific manifest has been generated, the script will deploy to the identified edge device.

    # Create or replace .env file for generating manifest file and copy content from environment file from user to .env file
    # We are copying the content to .env file as it's required by iotedgedev service

    # if [ "$CREATE_AZURE_MONITOR" == "true" ]; then
    #     echo "$(info) Updating Azure Monitor variables in \"$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME\""
    #     # Update Azure Monitor Values in env.template file
    #     sed -i "s/^\(TELEGRF_AZURE_TENANT_ID\s*=\s*\).*\$/\1$TELEGRAF_AZURE_TENANT_ID/" "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
    #     sed -i "s/^\(TELEGRF_AZURE_CLIENT_ID\s*=\s*\).*\$/\1$TELEGRAF_AZURE_CLIENT_ID/" "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
    #     sed -i "s/^\(TELEGRF_AZURE_CLIENT_SECRET\s*=\s*\).*\$/\1$TELEGRAF_AZURE_CLIENT_SECRET/" "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
    #     echo "$(info) Completed Update of Azure Monitor variables in \"$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME\""
    # fi

    # Update the value of RUNTIME variable in environment variable file
    sed -i 's#^\(RUNTIME[ ]*=\).*#\1\"'"$DETECTOR_MODULE_RUNTIME"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
    # Update the value of CAMERA_BLOB_SAS in the environment variable file with the SAS token for the images container
    sed -i "s|\(^CAMERA_BLOB_SAS=\).*|CAMERA_BLOB_SAS=\"${STORAGE_CONNECTION_STRING_WITH_SAS//\&/\\\&}\"|g" "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"

    # This step updates the video stream if specified in the variables.template file. This
    # is intended to let the user provide their own video stream instead of using the sample video provided as part of this repo.
    if [ -z "$CUSTOM_VIDEO_SOURCE" ]; then
        echo "$(info) Using default sample video to edge device"    
    else
        echo "$(info) Using custom video for edge deployment"
        
        if [[ "$CUSTOM_VIDEO_SOURCE" == rtsp://* ]]; then
            echo "$(info) RTSP URL: $CUSTOM_VIDEO_SOURCE"
            sed -i 's#^\(CROSSING_VIDEO_URL[ ]*=\).*#\1\"'"$CUSTOM_VIDEO_SOURCE"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
        else
            echo "$(error) Custom video source was not of format \"rtsp://path/to/video\". Please provide a valid RTSP URL"
            exitWithError
        fi
    fi

    echo "$(info) Copying variable values from \"$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME\" to .env"
    echo -n "" >.env
    cat "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME" >>.env
    echo "$(info) Copied values to .env"

    echo "$(info) Generating manifest file from template file"
    # Generate manifest file
    iotedgedev genconfig --file "$MANIFEST_TEMPLATE_NAME" --platform "$EDGE_DEVICE_ARCHITECTURE"

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
EXISTING_DEPLOYMENT_NAME=$(az iot edge deployment list --hub-name "$IOTHUB_NAME" --query "[?id=='$DEPLOYMENT_NAME'].{Id:id}" --output tsv)
if [ -z "$EXISTING_DEPLOYMENT_NAME" ]; then
    echo "$(info) Deploying \"$PRE_GENERATED_MANIFEST_FILENAME\" manifest file to \"$DEVICE_NAME\" Edge device"
    az iot edge deployment create --deployment-id "$DEPLOYMENT_NAME" --hub-name "$IOTHUB_NAME" --content "$PRE_GENERATED_MANIFEST_FILENAME" --target-condition "deviceId='$DEVICE_NAME'" --output "none"
else
    echo "$(info) Deployment \"$DEPLOYMENT_NAME\" already exists in IoT Hub \"$IOTHUB_NAME\""
    echo "$(info) Appending a random number \"$RANDOM_SUFFIX\" to Deployment name \"$DEPLOYMENT_NAME\""
    DEPLOYMENT_NAME=${DEPLOYMENT_NAME}${RANDOM_SUFFIX}
    # Writing the updated value back to variables file
    sed -i 's#^\(DEPLOYMENT_NAME[ ]*=\).*#\1\"'"$DEPLOYMENT_NAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
    echo "$(info) Deploying \"$PRE_GENERATED_MANIFEST_FILENAME\" manifest file to \"$DEVICE_NAME\" Edge device"
    az iot edge deployment create --deployment-id "$DEPLOYMENT_NAME" --hub-name "$IOTHUB_NAME" --content "$PRE_GENERATED_MANIFEST_FILENAME" --target-condition "deviceId='$DEVICE_NAME'" --output "none"
fi
echo "$(info) Deployed manifest file to IoT Hub. Your modules are being deployed to your device now. This may take some time."
