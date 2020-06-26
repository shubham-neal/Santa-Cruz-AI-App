# README


## Purpose:

This script automates deployment and setup of required resources for Person Tracking App

### Prerequisites

1. The script should be run on a linux machine
2. The following packages should be installed on the machine
	* iothub
	* azure-cli
	* azure-iot-edge-dev-tool
	* sshpass
3. azure-cli-iot-ext extension should be installed for azure cli
4. The user or service principal should have access to create resources in the given subscription in Azure
5. The user/service principal should have access to register applications in active directory
	* In case of service principal, it needs to have the following Application permissions in Azure Active directory
	    * Application.ReadWrite.All
	    * Application.ReadWrite.OwnedBy
	    * Directory.ReadWrite.All
        * Directory.Read.All		
6. When using a service principal to authenticate, provide it access to create other service principles for Azure Monitor step
7. Either a pre generated deployment manifest or a manifest template file with environment file should be present in the same directory as the script
8. Port for SSH should be enabled on the Edge machine
9. Appropriate ports should be opened on the Edge machine to allow iotedge service to send messages to IoT Hub
10. User running the script should have access to create directories and files on the machine
11. Set values in the variables.template file before running the script


### Variables in variables.template file:

|Name |Description  |
|---|---|
|TENANT_ID|Provide tenant id of your organization here   |
|SUBSCRIPTION_ID|Provide subscription id here   |
|RESOURCE_GROUP|Name of a resource group which will be created for the app. This should not be already present in the tenant   |
|LOCATION|Azure Data Centre location for the resource group and resources. Exp. East US   |
|IOTHUB_NAME|Name of the IoT Hub   |
|DEVICE_NAME|Name of the IoT Edge device on IoT Hub   |
|SP_APP_ID|ID of the service principal which will be used to log into Azure   |
|SP_APP_PWD|Secret of the service principal which will be used to log into Azure   |
|AZURE_MONITOR_SP_NAME|Service Principal name of the Azure Monitor service   |
|EDGE_DEVICE_IP|IP of the Edge device   |
|EDGE_DEVICE_USERNAME|Username of an account on Edge device, this account should have access to modify files on Edge device   |
|EDGE_DEVICE_PASSWORD|Password for the account on Edge device   |
|MANIFEST_TEMPLATE_NAME|Name of the template manifest file   |
|MANIFEST_ENVIRONMENT_VARIABLES_FILENAME|Name of the environment variable file containing values/secret   |
|PRE_GENERATED_MANIFEST_FILENAME|Name of the pre-generated manifest file. If this is not empty, this file will be used for deployment on Edge device. In case this is empty, the manifest template and environment files will be used to generate a manifest file.	|
|PUSH_RESULTS_TO_ADLS|If this is not empty, the data sent to IoT Hub will be pushed to ADLS container	|
|STORAGE_ACCOUNT_NAME|Storage account name for ADLS	|
|BLOBCONTAINER_NAME|Container name for ADLS	|
|ADLS_ENDPOINT_NAME|Endpoint for Edge device in IoT Hub	|
|IOTHUB_ADLS_ROUTENAME|Route name for the data to be pushed to ADLS in IoT Hub	|
|LOG_FILE|Name or path of the file to store execution logs	|
|USE_EXISTING_RG|Whether to use an existing Resource Group. Value should be "true" to use an existing resource group	|
|USE_EXISTING_IOT_HUB|Whether to use a existing IoT Hub. Value should be "true" to use an existing IoT Hub	|