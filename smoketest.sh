#!/bin/bash

#List of checks done by script:
#1.  IoT Edge Service is running or not on Edge machine.
#2.  Resource Group is present or not.
#3.  IoT Hub is present or not in Resource Group.
#4.  IoT Hub Device is present or not.
#5.  Default Route for built-in Event Hub endpoint is present or not in IoT Hub.
#6.  Storage account is present or not in the resource group.
#7.  Containers are present or not in Storage account.
#8.  Custom Data Lake Storage endpoint is present or not in IoT Hub.
#9.  Route to a Data Lake Storage account is present or not in IoT Hub.
#10. Data files are present or not in both 'detectoroutput' & still-images storage account containers.
#11. Deployment of manifest file is successfully applied to the edge device or not.
#12. Validating the runtimeStatus of each configured module on Edge device.
#13. App Service plan is present or not in Resource Group.
#14. Web App is present or not in Resource Group.

# The script currently does not handle the scenario where the endpoint in IoT Hub has a random number appended to it from the setup script during execution


# Stop execution on any error in script execution
set -e

# Define helper function for logging. This will change the Error text color to red
error() {
  tput setaf 1
}

# Reset console color
RESET_COLOR=$(tput sgr0)

SETUP_VARIABLES_TEMPLATE_FILENAME="variables.template"

if [ ! -f "$SETUP_VARIABLES_TEMPLATE_FILENAME" ]; then
  echo "$(error)\"$SETUP_VARIABLES_TEMPLATE_FILENAME\" file is not present in current directory: \"$PWD\" ${RESET_COLOR}"
  exit 1
fi

# The following comment is for ignoring the source file check for shellcheck, as it does not support variable source file names currently
# shellcheck source=variables.template
# Read variable values from variables.template file in current directory
source "$SETUP_VARIABLES_TEMPLATE_FILENAME"

# Set the variable value to decide, Whether to perform test for frontend app setup or not:
RUN_WEBAPP_CHECKS="true"

if [ "$RUN_WEBAPP_CHECKS" == "true" ]; then
  FRONTEND_VARIABLES_TEMPLATE_FILENAME="frontend-variables.template"
  
  if [ ! -f "$FRONTEND_VARIABLES_TEMPLATE_FILENAME" ]; then
    echo "$(error)\"$FRONTEND_VARIABLES_TEMPLATE_FILENAME\" file is not present in current directory: \"$PWD\"${RESET_COLOR}"
    exit 1
  fi
  # The following comment is for ignoring the source file check for shellcheck, as it does not support variable source file names currently
  # shellcheck source=variables.template
  # Read variable values from FRONTEND_VARIABLES_TEMPLATE_FILENAME file in current directory
  source "$FRONTEND_VARIABLES_TEMPLATE_FILENAME"
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
    PATH=~/usr/bin:$PATH
    # Remove the package file
    rm sshpass*.deb

        if [ -z "$(command -v sshpass)" ]; then
            echo "$(error)sshpass is not installed"
            exitWithError
        else
            echo "$(info) Installed sshpass"
        fi
    fi

    if [[ $(az extension list --query "[?name=='azure-cli-iot-ext'].name" --output tsv | wc -c) -eq 0 ]]; then
            echo "$(info) Installing azure-cli-iot-ext extension"
            az extension add --name azure-cli-iot-ext
    fi

    # jq is pre-installed in the cloud shell 

elif [ "$INSTALL_REQUIRED_PACKAGES" == "true" ]; then

    # We will check if any of the following package manager are installed in current machine:
    # apt, yum, dnf, zypper
    PACKAGE_MANAGER=""
    PACKAGE_MANAGER_VERSION_APT=$(command -v apt)
    PACKAGE_MANAGER_VERSION_YUM=$(command -v yum)
    PACKAGE_MANAGER_VERSION_DNF=$(command -v dnf)
    PACKAGE_MANAGER_VERSION_ZYPPER=$(command -v zypper)

    if [ ! -z "$PACKAGE_MANAGER_VERSION_APT" ]; then
        PACKAGE_MANAGER="apt"
    elif [ ! -z "$PACKAGE_MANAGER_VERSION_YUM" ]; then
        PACKAGE_MANAGER="yum"
    elif [ ! -z "$PACKAGE_MANAGER_VERSION_DNF" ]; then
        PACKAGE_MANAGER="dnf"
    elif [ ! -z "$PACKAGE_MANAGER_VERSION_ZYPPER" ]; then
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

        if [[ $(az extension list --query "[?name=='azure-cli-iot-ext'].name" --output tsv | wc -c) -eq 0 ]]; then
            echo "$(info) Installing azure-cli-iot-ext extension"
            az extension add --name azure-cli-iot-ext
        fi

        echo "$(info) Package Installation step is complete"
    fi
fi

# Log into azure either in a interactive way or non-interactive way based on a "USE_INTERACTIVE_LOGIN_FOR_AZURE" variable value
if [ "$USE_INTERACTIVE_LOGIN_FOR_AZURE" == "true" ]; then
  echo "[INFO] Attempting Login with User Authentication"

  az login --tenant "$TENANT_ID"

  echo "[INFO] Login Successful"

else
  echo "[INFO] Attempting Login with Service Principal Account"

  # Using service principal as it will not require user interaction
  az login --service-principal --username "$SP_APP_ID" --password "$SP_APP_PWD" --tenant "$TENANT_ID" --output "none"

  echo "[INFO] Login Successful"
fi

echo "[INFO] Setting current subscription to $SUBSCRIPTION_ID"

az account set --subscription "$SUBSCRIPTION_ID"

echo "[INFO] Set current subscription to $SUBSCRIPTION_ID"

# Check for Resource Group, if it exists with the same name provided in variable template then pass the check else throw error
if [ "$(az group exists -n "$RESOURCE_GROUP")" = false ]; then
  echo "$(error)Failed: Resource Group \"$RESOURCE_GROUP\" is not present. ${RESET_COLOR}"

else

  echo "Passed: Resource Group \"$RESOURCE_GROUP\" is present"
fi

# Check for IoT Hub, if it exists with the same name as in variable template then pass the test else throw error
if [ -z "$(az iot hub list --query "[?name=='$IOTHUB_NAME'].{Name:name}" -o tsv)" ]; then
  echo "$(error)Failed: IoT Hub \"$IOTHUB_NAME\" is not present. ${RESET_COLOR}"

else

  echo "Passed: IoT Hub \"$IOTHUB_NAME\" is present"
fi

# Retrieve IoT Edge device name to check whether it has been registered on IoT Hub or not
DEVICE=$(az iot hub device-identity list --hub-name "$IOTHUB_NAME" --query "[?deviceId=='$DEVICE_NAME'].deviceId" -o tsv)

# Check for IoT Edge Device identity on IoT Hub, if it exists with the same name as in variable template then pass the test else throw error
if [ -z "$DEVICE" ]; then
  echo "$(error)Failed: Device \"$DEVICE_NAME\" is not present in IoT Hub \"$IOTHUB_NAME\". ${RESET_COLOR}"

else

  echo "Passed: Device \"$DEVICE_NAME\" is present in IoT Hub \"$IOTHUB_NAME\""
fi

# Check for Default Route for built-in Event Hub endpoint
EXISTING_DEFAULT_ROUTE=$(az iot hub route list --hub-name "$IOTHUB_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='defaultroute'].name" --output tsv)
if [ -z "$EXISTING_DEFAULT_ROUTE" ]; then
  echo "$(error)Failed: Default Route for built-in Event Hub endpoint is not present in IoT Hub \"$IOTHUB_NAME\". ${RESET_COLOR}"

else

  echo "Passed: Default Route for built-in Event Hub endpoint is present in IoT Hub \"$IOTHUB_NAME\""
fi

# Retrieve the name of Storage account to check if it exists
STORAGE_ACCOUNT=$(az storage account list -g "$RESOURCE_GROUP" --query "[?name=='$STORAGE_ACCOUNT_NAME'].name" -o tsv)

# Check for Storage account, if it exists with same name as in variable template then pass the test else throw error
if [ -z "$STORAGE_ACCOUNT" ]; then
  echo "$(error)Failed: Storage account \"$STORAGE_ACCOUNT_NAME\" is not present. ${RESET_COLOR}"

else

  echo "Passed: Storage account \"$STORAGE_ACCOUNT_NAME\" is present"
fi

# Retrieve account key to check for container existence
STORAGE_ACCOUNT_KEY=$(az storage account keys list --resource-group "$RESOURCE_GROUP" --account-name "$STORAGE_ACCOUNT_NAME" --query "[0].value" | tr -d '"')

DETECTOR_OUTPUT_CONTAINER_NAME="detectoroutput"
# Retrieve status of container existence
CONTAINER=$(az storage container exists --name "$DETECTOR_OUTPUT_CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" -o tsv)

# Check for Container, if it exists with same name as in variable template pass the test else throw error
if [ "$CONTAINER" == "True" ]; then
  echo "Passed: Container \"$DETECTOR_OUTPUT_CONTAINER_NAME\" is present in \"$STORAGE_ACCOUNT_NAME\" Storage account"

else
  echo "$(error)Failed: Container \"$DETECTOR_OUTPUT_CONTAINER_NAME\" is not present in \"$STORAGE_ACCOUNT_NAME\" Storage account. ${RESET_COLOR}"

fi

IMAGES_CONTAINER_NAME="still-images"
# Retrieve status of container existence
CONTAINER=$(az storage container exists --name "$IMAGES_CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" -o tsv)

# Check for Container, if it exists with same name as in variable template pass the test else throw error
if [ "$CONTAINER" == "True" ]; then
  echo "Passed: Container \"$IMAGES_CONTAINER_NAME\" is present in \"$STORAGE_ACCOUNT_NAME\" Storage account"

else
  echo "$(error)Failed: Container \"$IMAGES_CONTAINER_NAME\" is not present in \"$STORAGE_ACCOUNT_NAME\" Storage account. ${RESET_COLOR}"

fi

ADLS_ENDPOINT_NAME="adls-endpoint"

# Check for Data Lake Storage endpoint in IoT Hub, if it exists with the same name as in variable template pass the test else throw error
if [ -z "$(az iot hub routing-endpoint list -g "$RESOURCE_GROUP" --hub-name "$IOTHUB_NAME" --endpoint-type azurestoragecontainer --query "[?name=='$ADLS_ENDPOINT_NAME'].name" -o tsv)" ]; then
  echo "$(error)Failed: Data Lake Storage endpoint \"$ADLS_ENDPOINT_NAME\" is not present in IoT Hub \"$IOTHUB_NAME\". ${RESET_COLOR}"

else

  echo "Passed: Data Lake Storage endpoint \"$ADLS_ENDPOINT_NAME\" is present in IoT Hub \"$IOTHUB_NAME\""
fi

IOTHUB_ADLS_ROUTENAME="adls-route"

# Check for Route to a Data Lake Storage account in IoT Hub, if it exists then pass the test else throw error
if [ -n "$(az iot hub route list -g "$RESOURCE_GROUP" --hub-name "$IOTHUB_NAME" --query "[?name=='$IOTHUB_ADLS_ROUTENAME'].name" -o tsv)" ]; then
  echo "Passed: Route to a Data Lake Storage account \"$IOTHUB_ADLS_ROUTENAME\" is present in IoT Hub \"$IOTHUB_NAME\" "

else
  echo "$(error)Failed: Route to a Data Lake Storage account \"$IOTHUB_ADLS_ROUTENAME\" is not present in IoT Hub \"$IOTHUB_NAME\". ${RESET_COLOR}"

fi

# Retrieve the file names and last modified date for files in data lake container
DETECTOR_OUTPUT_CONTAINER_DATA=$(az storage fs file list -f "$DETECTOR_OUTPUT_CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" --query "[*].{name:name}" -o table)

# Check for data in data lake, if any files exist in container after setup pass the test else throw error
if [ -n "$DETECTOR_OUTPUT_CONTAINER_DATA" ]; then
  echo "Passed: Data is present in the container \"$DETECTOR_OUTPUT_CONTAINER_NAME\" of \"$STORAGE_ACCOUNT_NAME\" Storage account"
else
  echo "$(error)Failed: Data is not present in the container \"$DETECTOR_OUTPUT_CONTAINER_NAME\" of \"$STORAGE_ACCOUNT_NAME\" Storage account. ${RESET_COLOR}"

fi

# Retrieve the file names and last modified date for files in data lake container
IMAGES_CONTAINER_CONTAINER_DATA=$(az storage fs file list -f "$IMAGES_CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" --query "[*].{name:name}" -o table)

# Check for data in data lake, if any files exist in container after setup pass the test else throw error
if [ -n "$IMAGES_CONTAINER_CONTAINER_DATA" ]; then
  echo "Passed: Data is present in the container \"$IMAGES_CONTAINER_NAME\" of \"$STORAGE_ACCOUNT_NAME\" Storage account"
else
  echo "$(error)Failed: Data is not present in the container \"$IMAGES_CONTAINER_NAME\" of \"$STORAGE_ACCOUNT_NAME\" Storage account. ${RESET_COLOR}"

fi

# Retrieve the deployment details for applied deployments on IoT Hub
DEPLOYMENT_STATUS=$(az iot edge deployment show-metric -m appliedCount --config-id "$DEPLOYMENT_NAME" --hub-name "$IOTHUB_NAME" --metric-type system --query "result" -o tsv)

# Check if the current applied deployment is the one variables.template file, if it is pass the test else throw error
if [ "$DEPLOYMENT_STATUS" == "$DEVICE_NAME" ]; then
  echo "Passed: Deployment is Applied on Edge Device \"$DEVICE_NAME\" "

else
  echo "$(error)Failed: Deployment is not Applied on Edge Device \"$DEVICE_NAME\". ${RESET_COLOR}"

fi

# Check the status of IoT Edge Service
# Use sshpass to run the check on a remote device
RUNNING_STATUS_COMMAND="sudo systemctl --type=service --state=running | grep -i \"iotedge\" "
INSTALLATION_STATUS_COMMAND="sudo systemctl --type=service | grep -i \"iotedge\" "

# Check if status of iotedge service is running on Edge Device
RUNNING_STATUS=$(sshpass -p "$EDGE_DEVICE_PASSWORD" ssh "$EDGE_DEVICE_USERNAME"@"$EDGE_DEVICE_IP" -o StrictHostKeyChecking=no "$RUNNING_STATUS_COMMAND")

# Check if iotedge service is installed on Edge Device
INSTALLATION_STATUS=$(sshpass -p "$EDGE_DEVICE_PASSWORD" ssh "$EDGE_DEVICE_USERNAME"@"$EDGE_DEVICE_IP" -o StrictHostKeyChecking=no "$INSTALLATION_STATUS_COMMAND")

if [ -n "$RUNNING_STATUS" ]; then
  echo "Passed: IoT Edge Service is installed and running on Edge Device"

else
  if [ -n "$INSTALLATION_STATUS" ]; then
    echo "$(error)Failed: IoT Edge Service is installed but not running on Edge Device. ${RESET_COLOR}"

  else

    echo "$(error)Failed: IoT Edge Service is not installed on Edge Device. ${RESET_COLOR}"

  fi
fi

# Retreive all details of modules configured on Edge device
EDGE_AGENT_TWIN=$(az iot hub module-twin show --module-id "\$edgeAgent" --hub-name "$IOTHUB_NAME" --device-id "$DEVICE_NAME")
# Retreive names of modules configured on Edge device
DEVICE_MODULES=$(echo "$EDGE_AGENT_TWIN" | jq -r '.properties.desired.modules' | jq -r 'to_entries[].key')
FAILED_STATUS_ARRAY=()

echo "$(info) Checking modules status"
# Checking the runtimeStatus of each configured module on Edge device from IoT Hub
for DEVICE_MODULE in ${DEVICE_MODULES[*]}; do
  # Count 60 is no. retries for checking status after 2second interval
  for ((i = 1; i <= 60; i++)); do
    # Retreive all the configured module details on Edge device from IoT Hub
    EDGE_AGENT_TWIN=$(az iot hub module-twin show --module-id "\$edgeAgent" --hub-name "$IOTHUB_NAME" --device-id "$DEVICE_NAME")
    MODULE_STATUS=$(echo "$EDGE_AGENT_TWIN" | jq -r .properties.reported.modules[\""$DEVICE_MODULE"\"].runtimeStatus)

    if [ "$MODULE_STATUS" == "running" ]; then
      break
    else
      sleep 2s
    fi
  done
  if [ "$MODULE_STATUS" != "running" ]; then
    FAILED_STATUS_ARRAY+=("$DEVICE_MODULE")
  fi
done

# Check for module status
# Print Success or Failure based on the length of array:
if [ "${#DEVICE_MODULES[*]}" -gt 0 ] && [ "${#FAILED_STATUS_ARRAY[@]}" -gt 0 ]; then
  echo "$(error)Failed: RuntimeStatus of following modules are not running on IoT Hub."
  printf '%s\n' "Modules: ${FAILED_STATUS_ARRAY[*]} ${RESET_COLOR}"

else
  if [ "${#DEVICE_MODULES[*]}" -gt 0 ]; then
    echo "Passed: RuntimeStatus of following configured modules are running on IoT Hub."
    printf '%s\n' "Modules: ${DEVICE_MODULES[*]}"
  else
    echo "$(error)Failed: Modules are not yet configured on IoT Hub. ${RESET_COLOR}"
  fi
fi

# Checks for Frontend app setup in Resource Group:
if [ "$RUN_WEBAPP_CHECKS" == "true" ]; then

  # Check if App Service plan is created or not in Resource Group:
  if [ -n "$(az appservice plan show --name "$APP_SERVICE_PLAN_NAME" --resource-group "$RESOURCE_GROUP" --query "name" -o tsv)" ]; then

    echo "Passed: App Service plan \"$APP_SERVICE_PLAN_NAME\" is present in Resoure group \"$RESOURCE_GROUP\"."

  else
    echo "$(error)Failed: App Service plan \"$APP_SERVICE_PLAN_NAME\" is not present in Resoure group \"$RESOURCE_GROUP\". ${RESET_COLOR}"

  fi

  # Check if Web App is created or not in Resource Group:
  if [ -n "$(az webapp show --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" --query "name" -o tsv)" ]; then

    echo "Passed: Web App \"$WEBAPP_NAME\" is present in Resoure group \"$RESOURCE_GROUP\"."
  else

    echo "$(error)Failed: Web App \"$WEBAPP_NAME\" is not present in Resoure group \"$RESOURCE_GROUP\". ${RESET_COLOR}"

  fi
fi
