# README


## Purpose:

This script automates deployment and setup of required resources for Person Tracking App

### Prerequisites

1. The script should be run on a linux machine
2. The following packages should be installed on the machine
	* azure-cli
	* iotedgedev
	* sshpass
    * jq
    * curl
3. azure-cli-iot-ext extension should be installed for azure cli
4. The user or service principal should have access to create resources in the given subscription in Azure
5. The user/service principal should have access to register applications in active directory
	* In case of service principal, it needs to have the following Azure Active Directory Graph Application permissions
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
|USE_EXISTING_RG|If the value is set to "yes", the script will use an existing resource if it present in Azure. If it is not set to true, the script will fail is there is already an existing resource with the given name in Azure|
|RESOURCE_GROUP|Name of a resource group which will be created for the app.    |
|LOCATION|Azure Data Centre location for the resource group and resources. Exp. East US   |
|IOTHUB_NAME|Name of the IoT Hub   |
|USE_EXISTING_IOT_HUB|If the value is set to "yes", the script will use an existing resource if it present in Azure. If it is not set to true, the script will fail is there is already an existing resource with the given name in Azure	|
|DEVICE_NAME|Name of the IoT Edge device on IoT Hub   |
|USE_EXISTING_IOT_HUB_DEVICE|If the value is set to "yes", the script will use an existing resource if it present in Azure. If it is not set to true, the script will fail is there is already an existing resource with the given name in Azure|
|DEPLOYMENT_NAME|Name of the deployment on the Edge device in IoT Hub. Please note that this should be unique for each deployment|
|USE_INTERACTIVE_LOGIN_FOR_AZURE|If value is set to "true", the script will prompt the user for authentication. If it is not set to true, non-interactive login with service principal will be used|
|SP_APP_ID|ID of the service principal which will be used to log into Azure. This is required if USE_INTERACTIVE_LOGIN_FOR_AZURE is not set to "true"   |
|SP_APP_PWD|Secret of the service principal which will be used to log into Azure. This is required if USE_INTERACTIVE_LOGIN_FOR_AZURE is not set to "true"   |
|CREATE_AZURE_MONITOR|If the value is set to "true", a new service principal with monitor role on the IoT hub will be created and the values will be set in the deployment template file |
|AZURE_MONITOR_SP_NAME|Service Principal name of the Azure Monitor service  |
|IS_THE_SCRIPT_RUNNING_FROM_EDGE_DEVICE|Value should be "true" if the script is running on the Edge device|
|EDGE_DEVICE_IP|IP of the Edge device. This is required if IS_THE_SCRIPT_RUNNING_FROM_EDGE_DEVICE is not set to "true"  |
|EDGE_DEVICE_USERNAME|Username of an account on Edge device, this account should have access to modify files on Edge device. This is required if IS_THE_SCRIPT_RUNNING_FROM_EDGE_DEVICE is not set to "true"   |
|EDGE_DEVICE_PASSWORD|Password for the account on Edge device. This is required if IS_THE_SCRIPT_RUNNING_FROM_EDGE_DEVICE is not set to "true"  |
|MANIFEST_TEMPLATE_NAME|Name of the template manifest file   |
|MANIFEST_ENVIRONMENT_VARIABLES_FILENAME|Name of the environment variable file containing values/secret   |
|PRE_GENERATED_MANIFEST_FILENAME|Name of the pre-generated manifest file. If this is not empty, this file will be used for deployment on Edge device. In case this is empty, the manifest template and environment files will be used to generate a manifest file.	|
|PUSH_RESULTS_TO_ADLS|If the value is set to "true", telemetry data will be pushed to ADLS	|
|STORAGE_ACCOUNT_NAME|Storage account name for ADLS. This is required if PUSH_RESULTS_TO_ADLS is set to "true"	|
|BLOBCONTAINER_NAME|Container name for ADLS. This is required if PUSH_RESULTS_TO_ADLS is set to "true"	|
|ADLS_ENDPOINT_NAME|Custom Data Lake Endpoint for Edge device in IoT Hub. This is required if PUSH_RESULTS_TO_ADLS is set to "true"	|
|IOTHUB_ADLS_ROUTENAME|Route name for the data to be pushed to ADLS in IoT Hub. This is required if PUSH_RESULTS_TO_ADLS is set to "true"	|
|ADLS_ROUTING_CONDITION|Condition for filtering the routing data for adls route |
|PUSH_RESULTS_TO_EVENT_HUB|If the value is set to "true", the script will set up required resources to enable data push to event hub|
|EVENTHUB_NAMESPACE|Name of the event hub namespace. This is required if PUSH_RESULTS_TO_EVENT_HUB is set to "true" |
|EVENTHUB_NAME|Name of the event hub. This is required if PUSH_RESULTS_TO_EVENT_HUB is set to "true" |
|EVENTHUB_ROUTENAME|Name of the route that will push data to event hub through event hub custom endpoint. This is required if PUSH_RESULTS_TO_EVENT_HUB is set to "true"|
|EVENTHUB_ENDPOINT_NAME| Name of the custom endpoint that will be created to push data to Event Hub. This is required if PUSH_RESULTS_TO_EVENT_HUB is set to "true"|
|EVENTHUB_ROUTING_CONDITION| Condition for filtering the routing data for event hub route|