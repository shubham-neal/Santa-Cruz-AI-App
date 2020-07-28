#!/usr/bin/env bash

# This script creates a Azure VM using a managed disk.
# It performs the following steps:
#	1. Login to Azure
#	2. Create an empty managed disk in ForUpload state
#	3. Generate a SAS Token for the managed disk
#	4. Copy the vhd blob file from a storage container to managed disk using AzCopy
#	5. Remove the SAS Token. This will changed the state from ForUpload to Unattached
#   6. Create a VM from managed disk.

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

SETUP_VARIABLES_TEMPLATE_FILENAME="mariner-vm-variables.template"

if [ ! -f "$SETUP_VARIABLES_TEMPLATE_FILENAME" ]; then
    echo "$(error) \"$SETUP_VARIABLES_TEMPLATE_FILENAME\" file is not present in current directory: \"$PWD\""
    exitWithError
fi

# The following comment is required for shellcheck, as it does not support variable source file names.
# shellcheck source=mariner-vm-variables.template
# Read variable values from SETUP_VARIABLES_TEMPLATE_FILENAME file in current directory
source "$SETUP_VARIABLES_TEMPLATE_FILENAME"

# Check value of POWERSHELL_DISTRIBUTION_CHANNEL. This variable is present in Azure Cloud Shell environment.
# There are different installation steps for Cloud Shell as it does not allow root access to the script
# In Azure Cloud Shell, azcopy and jq are pre-installed so skip the step
if [ ! "$POWERSHELL_DISTRIBUTION_CHANNEL" == "CloudShell" ] && [ "$INSTALL_REQUIRED_PACKAGES" == "true" ]; then

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
        sudo "$PACKAGE_MANAGER" install wget

        echo "$(info) Installing AzCopy"

        CURRENT_DIRECTORY="$PWD"
        wget https://aka.ms/downloadazcopy-v10-linux -O downloadazcopy-v10-linux
        # unzipping the downloaded archive
        tar -xvf downloadazcopy-v10-linux
        # changing directory to fetch the azcopy executable
        cd azcopy_linux*/
        # Add azcopy to /usr/bin directory
        sudo cp azcopy /usr/bin/
        # Return to original directory
        cd "$CURRENT_DIRECTORY"
        # Remove the downloaded files
        rm azcopy_linux* -r
        rm downloadazcopy-v10-linux

        echo "$(info) Installed AzCopy "

        echo "$(info) Installing jq"
        sudo "$PACKAGE_MANAGER" install jq
        echo "$(info) Installed jq"

        echo "$(info) Installing curl"
        sudo "$PACKAGE_MANAGER" install curl
        echo "$(info) Installed curl"
    fi
fi

printf "\n%60s\n" " " | tr ' ' '-'
echo "Checking if the required variables are configured"
printf "%60s\n" " " | tr ' ' '-'

# Checking the existence and values of mandatory variables

# Setting default values for variable check stage
ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY="true"
ARRAY_VARIABLES_WITHOUT_VALUES=()
ARRAY_NOT_DEFINED_VARIABLES=()

# Pass the name of the variable and it's value to the checkValue function
checkValue "TENANT_ID" "$TENANT_ID"
checkValue "SUBSCRIPTION_ID" "$SUBSCRIPTION_ID"
checkValue "RESOURCE_GROUP" "$RESOURCE_GROUP"
checkValue "LOCATION" "$LOCATION"
checkValue "USE_EXISTING_RESOURCE_GROUP" "$USE_EXISTING_RESOURCE_GROUP"

IS_NOT_EMPTY=$(checkValue "USE_INTERACTIVE_LOGIN_FOR_AZURE" "$USE_INTERACTIVE_LOGIN_FOR_AZURE" "RETURN_VARIABLE_STATUS")
if [ "$IS_NOT_EMPTY" == "1" ] && [ "$USE_INTERACTIVE_LOGIN_FOR_AZURE" == "true" ]; then
    checkValue "SP_APP_ID" "$SP_APP_ID"
    checkValue "SP_APP_PWD" "$SP_APP_PWD"
fi

if [ -z "$DISK_NAME" ]; then
    # Value is empty for DISK_NAME;
    # Assign Default value
    DISK_NAME="mariner"
fi

if [ -z "$STORAGE_TYPE" ]; then
    # Value is empty for STORAGE_TYPE;
    # Assign Default value
    STORAGE_TYPE="Premium_LRS"
fi

if [ -z "$VM_NAME" ]; then
    # Value is empty for VM_NAME;
    # Assign Default value
    VM_NAME="marinervm"
fi

if [ -z "$VM_SIZE" ]; then
    # Value is empty for VM_SIZE;
    # Assign Default value
    VM_SIZE="Standard_DS2_v2"
fi

# Generate NSG name by appending -nsg to VM name
NSG_NAME="${VM_NAME}-nsg"

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

# VHD_URI is the direct link for VHD file in storage account. The VHD file must be in the current subscription
VHD_URI="https://georgembbox.blob.core.windows.net/brainbox/brainbox-dev-1.0.MM5.20200603.2120.v0.0.3.vhd?sp=r&st=2020-07-24T21:41:00Z&se=2021-01-01T08:00:00Z&spr=https&sv=2019-12-12&sr=b&sig=E%2Fe2SO2W25SZhxtCwUzUIj00B60k6iuzuWazWUy%2FyKA%3D"

# Whether to create a rule in NSG for SSH or RDP.
# The following are the allowed values:
# 	NONE: Do not create any inbound security rule in NSG for RDP or SSH ports. (Recommended)
# 	SSH: Create an inbound security rule in NSG with priority 1000 for SSH port (22)
#	RDP: Create an inbound security rule in NSG with priority 1000 for RDP port (3389)
NSG_RULE="NONE"

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

if [ "$(az group exists --name "$RESOURCE_GROUP")" == false ]; then
    echo "$(info) Creating a new Resource Group: \"$RESOURCE_GROUP\""
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    echo "$(info) Successfully created resource group"
else
    if [ "$USE_EXISTING_RESOURCE_GROUP" == "true" ]; then
        echo "$(info) Using Existing Resource Group: \"$RESOURCE_GROUP\""
    else
        echo "$(error) Resource Group \"$RESOURCE_GROUP\" already exists"
        exitWithError
    fi
fi

printf "\n%60s\n" " " | tr ' ' '-'
echo "Managed disk \"$DISK_NAME\" setup"
printf "%60s\n" " " | tr ' ' '-'

# Check if disk already exists
EXISTING_DISK=$(az disk list --resource-group "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" --query "[?name=='$DISK_NAME'].{Name:name}" --output tsv)
if [ -z "$EXISTING_DISK" ]; then
    echo "$(info) Creating empty managed disk \"$DISK_NAME\""
    # The upload size bytes must be same as size of the VHD file
    az disk create -n "$DISK_NAME" -g "$RESOURCE_GROUP" -l "$LOCATION" --for-upload --upload-size-bytes 68719477248 --sku "$STORAGE_TYPE" --os-type "Linux" --hyper-v-generation "V2" --output "none"
    echo "$(info) Created empty managed disk \"$DISK_NAME\""
else
    echo "$(error) Managed Disk \"$DISK_NAME\" already exists in resource group \"$RESOURCE_GROUP\""
    exitWithError
fi

# This section grants access to the empty disk we created in the prior step through a temporary SAS token. We
# will use this token to allow azcopy to copy the private Mariner OS vhd file to another subscription. After the copy
# operation has completed, we revoke access to the disk in our environment to conclude the disk setup operation.
echo "$(info) Fetching the SAS Token for temporary access to managed disk"
SAS_URI=$(az disk grant-access -n "$DISK_NAME" -g "$RESOURCE_GROUP" --access-level Write --duration-in-seconds 86400)
TOKEN=$(echo "$SAS_URI" | jq -r '.accessSas')
echo "$(info) Retrieved the SAS Token"

echo "$(info) Copying vhd file from source to destination"
# Run azcopy if current envrionment is CloudShell else run sudo azcopy.
# azcopy needs to run as superuser in non Cloud Shell environment to be able to create plans
if [ "$POWERSHELL_DISTRIBUTION_CHANNEL" == "CloudShell" ]; then
    azcopy copy "$VHD_URI" "$TOKEN" --blob-type PageBlob
else
    sudo azcopy copy "$VHD_URI" "$TOKEN" --blob-type PageBlob
fi
echo "$(info) Copy is complete"

echo "$(info) Revoking SAS token access for the managed disk"
az disk revoke-access -n "$DISK_NAME" -g "$RESOURCE_GROUP" --output "none"
echo "$(info) SAS REVOKED"

echo "$(info) Managed disk setup is complete"

printf "\n%60s\n" " " | tr ' ' '-'
echo "Virtual machine \"$VM_NAME\" setup"
printf "%60s\n" " " | tr ' ' '-'

EXISTING_VM=$(az vm list --resource-group "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" --query "[?name=='$VM_NAME'].{Name:name}" --output tsv)
if [ -z "$EXISTING_VM" ]; then
    echo "$(info) Creating virtual machine \"$VM_NAME\""
    az vm create --name "$VM_NAME" --resource-group "$RESOURCE_GROUP" --attach-os-disk "$DISK_NAME" --os-type "linux" --location "$LOCATION" --nsg-rule "$NSG_RULE" --nsg "$NSG_NAME" --size "$VM_SIZE" --output "none"
    echo "$(info) Created virtual machine \"$VM_NAME\""
else
    echo "$(error) Virtual machine \"$VM_NAME\" already exists in resource group \"$RESOURCE_GROUP\""
    exitWithError
fi


CURRENT_IP_ADDRESS=$(curl -s https://ip4.seeip.org/)

echo "$(info) Adding current machine IP address \"$CURRENT_IP_ADDRESS\" in Network Security Group firewall"

# Create a NSG Rule to allow SSH for current machine
az network nsg rule create --name "AllowSSH" --nsg-name "$NSG_NAME" --priority 100 --resource-group "$RESOURCE_GROUP" --destination-port-ranges 22 --source-address-prefixes "$CURRENT_IP_ADDRESS" --output "none"

echo "$(info) Added current machine IP address \"$CURRENT_IP_ADDRESS\" in Network Security Group firewall"

EDGE_DEVICE_IP=$(az vm show --show-details --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --query "publicIps" --output tsv)

echo "The following are the details for the VM"
echo "IP Address: \"$EDGE_DEVICE_IP\""
echo "Username: \"root\""
echo "Password: \"p@ssw0rd\""
