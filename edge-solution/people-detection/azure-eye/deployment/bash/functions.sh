#!/bin/bash

printHelp() {
    echo "
    Mandatory Arguments
        --rg-ams                : Resource group name for Azure Media Service, Storage Accounts and Web App
        
    Optional Arguments
        --rg-device             : Resource group name for Azure Eye Device and IoT Hub. If it's not provided, it is same same rg-ams 
        --website-password      : Password to access the web app
        --help                  : Show this message and exit
	
    Examples:

    1. Deploy app with existing IoT Edge device
    sudo ./azure-eye-setup.sh --rg-ams rg-azureeye-ams 

    2. Deploy app without existing IoT Edge device
    sudo ./azure-eye-setup.sh -rg-iot rg-azureeye-ams --rg-device rg-azureeye-device
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


checkPackageInstallation() {

	if [ -z "$(command -v iotedge)" ]; then
		echo "$(error) IoT Runtime is not installed in current machine"
		exitWithError
	fi

	if [ -z "$(command -v az)" ]; then
        echo "$(info) Installing az cli"
		curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    fi

    if [[ $(az extension list --query "[?name=='azure-iot'].name" --output tsv | wc -c) -eq 0 ]]; then
        echo "$(info) Installing azure-iot extension"
        az extension add --name azure-iot
    fi
	
    if [ -z "$(command -v jq)" ]; then
        echo "$(info) Installing jq"
		sudo apt-get update
		sudo apt-get install jq
    fi
	
	if [ -z "$(command -v timeout)" ]; then
        echo "$(info) Installing timeout"
		sudo apt-get update
		sudo apt-get install timeout
    fi
}