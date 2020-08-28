#!/bin/bash

# Exit the script on any error
set -e

# This script will automate the cloudShell deployment of all setup scripts for azure resources;
# This script can be run in different scenarios:
# Pass only required arguments to test the deployment-bundle-latest zip in Test storage account
# 	eg: ./cloudshell-deployment.sh --device-runtime "CPU" --website-password "Password" --rg-iot "iotresourcegroup" --rg-vm "vmresourcegroup" --device-architecture "X86"



# SAS URL of DeploymentBundle zip.
SAS_URL="https://unifiededgescenarios.blob.core.windows.net/people-detection/deployment-bundle-latest.zip?sp=r&st=2020-08-12T13:17:07Z&se=2020-12-30T21:17:07Z&spr=https&sv=2019-12-12&sr=b&sig=%2BakjkDanqU5CczPmIVXz3gn8Bu3MWjB0vZ2IEnJoUKE%3D"

PRINT_HELP="false"

printHelp() {
    echo "Usage: ./cloudshell-deployment.sh --device-runtime \"CPU\" --website-password \"Password\" --rg-iot \"iotresourcegroup\" --rg-vm \"vmresourcegroup\" --device-architecture \"X86\"
    Arguments:
    --device-runtime        : AI execution hardware: set to 'CPU' for CPU-based dectector in cloud, 'MOVIDIUS' for Intel Myriad X VPU, or 'NVIDIA' to use Nvidia GPU
    --website-password      : Password to access the web app
    --rg-iot                : Resource group IoT Hub, Storage Accounts and Web App
    --rg-vm                 : Resource group for Edge Device vm
    --device-architecture   : Specify the CPU architecture of the Edge Device. Currently supported values are X86 and ARM64
	"
}

while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --website-password)
            PASSWORD_FOR_WEBSITE_LOGIN="$2"
            shift # past argument
            shift # past value
            ;;
        --rg-vm)
            RESOURCE_GROUP_DEVICE="$2"
            shift # past argument
            shift # past value
            ;;
        --rg-iot)
            RESOURCE_GROUP_IOT="$2"
            shift # past argument
            shift # past value
            ;;
        --device-architecture)
            EDGE_DEVICE_ARCHITECTURE="$2"
            shift # past argument
            shift # past value
            ;;
        --device-runtime)
            DETECTOR_MODULE_RUNTIME="$2"
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
fi

ARRAY_OF_MISSED_PARAMETERS=()
checkValue() {
    
    if [ -z "$2" ]; then
        # If the value is empty, add the variable name ($1) to ARRAY_OF_MISSED_PARAMETERS array 
        ARRAY_OF_MISSED_PARAMETERS+=("$1")
    fi
}

checkValue "--device-runtime" "$DETECTOR_MODULE_RUNTIME"
checkValue "--rg-iot" "$RESOURCE_GROUP_IOT"
checkValue "--rg-vm" "$RESOURCE_GROUP_DEVICE"
checkValue "--device-architecture" "$EDGE_DEVICE_ARCHITECTURE"
checkValue "--website-password" "$PASSWORD_FOR_WEBSITE_LOGIN"

if [ ${#ARRAY_OF_MISSED_PARAMETERS[*]} -gt 0 ]; then
    echo "Following required parameters are missing from the command: ${ARRAY_OF_MISSED_PARAMETERS[*]}"
    printHelp
    exit 0
else
    echo "All required variables are configured."
fi

echo "Downloading deployment bundle zip"

# Download the latest deployment-bundle.zip from storage account
wget -O deployment-bundle-latest.zip "$SAS_URL"

# Extracts all the files from zip in curent directory;
# overwrite existing ones
echo "Unzipping the files"
unzip -o deployment-bundle-latest.zip -d "deployment-bundle-latest"
cd deployment-bundle-latest
echo "Unzipped the files in directory deployment-bundle-latest"

# Update the variable.template file with values passed in arguments

sed -i 's#^\(DETECTOR_MODULE_RUNTIME[ ]*=\).*#\1\"'"$DETECTOR_MODULE_RUNTIME"'\"#g' "variables.template"

sed -i 's#^\(EDGE_DEVICE_ARCHITECTURE[ ]*=\).*#\1\"'"$EDGE_DEVICE_ARCHITECTURE"'\"#g' "variables.template"

sed -i 's#^\(RESOURCE_GROUP_DEVICE[ ]*=\).*#\1\"'"$RESOURCE_GROUP_DEVICE"'\"#g' "variables.template"

sed -i 's#^\(RESOURCE_GROUP_IOT[ ]*=\).*#\1\"'"$RESOURCE_GROUP_IOT"'\"#g' "variables.template"

sed -i 's#^\(PASSWORD_FOR_WEBSITE_LOGIN[ ]*=\).*#\1\"'"$PASSWORD_FOR_WEBSITE_LOGIN"'\"#g' "variables.template"

USE_INTERACTIVE_LOGIN_FOR_AZURE="false"
sed -i 's#^\(USE_INTERACTIVE_LOGIN_FOR_AZURE[ ]*=\).*#\1\"'"$USE_INTERACTIVE_LOGIN_FOR_AZURE"'\"#g' "variables.template"

# Read variable values from updated variable.template file
source "variables.template"

# Provide all the script paths to run
VM_SCRIPT_PATH="./eye-vm-setup.sh"
DEPLOY_IOT_SCRIPT_PATH="./deploy-iot.sh"
FRONTEND_SCRIPT_PATH="./frontend-setup.sh"

# Run your scripts in order:
printf "\n%60s\n" " " | tr ' ' '-'
echo "Running Eye VM Setup script"
printf "%60s\n" " " | tr ' ' '-'

"$VM_SCRIPT_PATH"

printf "\n%60s\n" " " | tr ' ' '-'
echo "Completed Eye VM Setup script"
printf "%60s\n" " " | tr ' ' '-'

printf "\n%60s\n" " " | tr ' ' '-'
echo "Running Deploy IoT Setup script"
printf "%60s\n" " " | tr ' ' '-'

"$DEPLOY_IOT_SCRIPT_PATH"

printf "\n%60s\n" " " | tr ' ' '-'
echo "Completed Deploy IoT Setup script"
printf "%60s\n" " " | tr ' ' '-'

printf "\n%60s\n" " " | tr ' ' '-'
echo "Running Frontend Setup script"
printf "%60s\n" " " | tr ' ' '-'

"$FRONTEND_SCRIPT_PATH"

printf "\n%60s\n" " " | tr ' ' '-'
echo "Completed Frontend Setup script"
printf "%60s\n" " " | tr ' ' '-'