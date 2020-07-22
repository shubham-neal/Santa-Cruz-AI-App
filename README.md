# Unified Edge Scenarios Deployment Guide

This document serves to walk through the end-user deployment and onboarding experience for the open source people detection on Azure Brainbox. 

## Changes to VHD
Several changes were necessary for making the VHD file so it can be deployed as an Azure VM. A detailed list of changes is listed below.

- IoT Edge Configuration
	- File: /etc/iotedge/config.yaml
	- Changes:
		- changed hostname to "brainbox"

- SSH configuration
	- File: /etc/ssh/sshd_config
	- Changes:
		- ClientAliveInterval 180
		- TCPKeepAlive yes
		- PermitRootLogin yes

Convert disk from vhdx to vhd using Hyper-V conversion tool
Expand disk from 10GB to 64GB using Hyper-V conversion tool
Upload VHD file to blob storage

## Brainbox VM Creation

Steps:
1. Create a new managed disk from VHD file

	Using shell script:
	1. Configure following variables in [setup-brainbox-managed-disk.sh](setup-brainbox-managed-disk.sh)


		|    Variable Name  | Is it Required? | Description |
		|---------------------|-------------|-------------|
		|    TENANT_ID  | Required |  ID for your tenant |
		|    SUBSCRIPTION_ID     | Required | ID for your subscription         |
		|    RESOURCE_GROUP | Required | Resource Group Name or ID          |
		|    LOCATION   | Required |  Azure Region location         |
		|    DISK_NAME   | Required |  Name for the managed disk that will be created          |
		|    USE_INTERACTIVE_LOGIN   | Required |  Set it to true to use interactive login. If it's not set to true, service principal will be used for login           |
		|    SP_APP_ID   | Optional |   Client ID of Service Principal for login. Only required if USE_INTERACTIVE_LOGIN is not set to true          |
		|    SP_APP_PWD   | Optional |  Client Secret of Service Principal for login. Only required if USE_INTERACTIVE_Login is not set to true           |

	2. Run the [setup-brainbox-managed-disk.sh](setup-brainbox-managed-disk.sh) script 

2. Create a new VM from disk

	Using Azure portal:
	1. Open the managed disk created in above step in Azure Portal
	2. Select "Create VM"

		![Create VM using Managed Disk](/MarkdownImages/create_vm_azure_portal_step_1.png)
		
	3. Provide name to the VM, select None in Public Inbound Ports and click on Create+Review

		![Create VM](/MarkdownImages/create_vm_azure_portal_step_2.png)

	4. Click on Create
	
		![Create VM](/MarkdownImages/obfuscated_create_vm_azure_portal_step_3.png)

	Using shell script:
	1. Configure following variables in [setup-brainbox-vm.sh](setup-brainbox-vm.sh)

		|    Variable Name  | Is it Required? | Description |
		|---------------------|-------------|-------------|
		|    VM_NAME  | Required |  Name of the VM that will be created |
		|    TENANT_ID  | Required |  ID for your tenant |
		|    SUBSCRIPTION_ID     | Required | ID for your subscription         |
		|    RESOURCE_GROUP | Required | Resource Group Name or ID          |
		|    LOCATION   | Required |  Azure Region location         |
		|    DISK_NAME   | Required |  Name for the managed disk that will be used to create VM          |
		|    USE_INTERACTIVE_LOGIN   | Required |  Set it to true to use interactive login. If it's not set to true, service principal will be used for login           |
		|    SP_APP_ID   | Optional |   Client ID of Service Principal for login. Only required if USE_INTERACTIVE_LOGIN is not set to true          |
		|    SP_APP_PWD   | Optional |  Client Secret of Service Principal for login. Only required if USE_INTERACTIVE_Login is not set to true           |		
	2. Run the [setup-brainbox-vm.sh](setup-brainbox-vm.sh) script 

3. Note down the public IP of the VM. This will be used later in deployment script as EDGE_DEVICE_IP.

	![Note down IP](/MarkdownImages/obfuscated_note_down_azure_vm_ip.png)

4. 	Add a SSH rule in Network Security Group of the VM to allow your machine to connect to VM. 
	
	Select Networking blade in VM on Azure Portal. Click on Add inbound port rule

	![Inbound SSH rule](/MarkdownImages/add_nsg_rule_step_1.png)	
	Add values in inbound port rule and select add.

	![Inbound SSH rule](/MarkdownImages/add_nsg_rule_step_2.png)

	If your tenant has enabled Azure Core Security Managed Policy, a default rule blocking SSH port may be auto added to the Network Security Group. You can update that rule to allow access to your IP.

5. Test connectivity to the Brainbox VM

	```
	ssh root@<brainbox-ip>
	Enter password when prompted
	```

	You should see a screen similar to the following when connected to the brainbox machine.

	![Test Connectivity](/MarkdownImages/brainbox_vm_screenshot.png)

## Automated Brainbox Setup / Onboarding

### Prerequisites

- Deployment machine must be a linux-based device. The instructions below have been tested on Ubuntu 18.04 LTS.
- The user or service principal should have access to create resources in the given subscription in Azure
- The user/service principal should have access to register applications in active directory
	* In case of service principal, it needs to have the following Azure Active Directory Graph Application permissions
	    * Application.ReadWrite.All
	    * Application.ReadWrite.OwnedBy
	    * Directory.ReadWrite.All
        * Directory.Read.All		
- When using a service principal to authenticate, provide it access to create other service principles for Azure Monitor step
- Appropriate ports should be opened on the Edge machine to allow iotedge service to send messages to IoT Hub
- User running the script should have access to create directories and files on the machine
- Set values in the [variables.template](variables.template) file before running the script
- The following packages are required for executing the setup script. Follow the below instructions to install

#### Install Package Dependencies

1. Install jq, sshpass, curl, python-pip packages using your package manager.
	
	The following commands use apt package manager in Ubuntu. 
	```sh
	 sudo apt update
	 sudo apt install -y curl jq sshpass python-pip
	 ```

1. Install Docker and restart your machine for it to take effect
	
	```sh
	curl -fsSL https://get.docker.com -o get-docker.sh
	sh get-docker.sh
	sudo usermod -aG docker $USER
	```

1. Install Azure CLI
	
	```
	curl -L https://aka.ms/InstallAzureCli | bash
	```

1. Install Azure CLI IoT Extension
	
	```
	az extension add --name azure-cli-iot-ext
	```

1. Install iotedgedev utility
	
	```
	pip install docker-compose
	pip install iotedgedev
	```

	You may need to run the below commands to allow your system to find iotedgedev
	```
	echo "PATH=~/.local/bin:$PATH" >> ~/.bashrc
	source ~/.bashrc
	```

	Test iotedgedev installation by running the below command
	```
	iotedgedev --version
	```
1. Install AzCopy

	Download AzCopy for linux from [here](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10#download-azcopy)

	Unzip the downloaded AzCopy gzip file

	Copy the azcopy executable from unzipped directory to /user/bin so it's available for use in the system

	```
	sudo cp ./azcopy_linux_amd64_*/azcopy /usr/bin/
	```

1. Install Node JS and npm

	```
	curl -sL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
	sudo apt-get install -y nodejs
	```

## Supported Deployment Scenarios:

### End to end deployment (Developer / dogfooding experience)
- Creates a new resource group, IoT Hub, Edge Device, and links physical edge device to IoT Hub
- Customizes the deployment for your environment
- Deploys the IoT Edge manifest to the edge device
	
### Edge Module Deployment (End-user unboxing experience)
- Uses an existing resource group, IoT Hub, and Edge Device that has already been onboarded
- Customizes the deployment for your environment
- Deploys the IoT Edge manifest to the edge device


### Fill in Variables in variables.template file for your Azure Deployment:
Before deploying, you will need to fill out the values in the variables.template file. A description of each value is provided in the table below:

|Name | Is it Required? |Description  |
|---|---|---|
|TENANT_ID| Required |Provide tenant id of your organization here   |
|SUBSCRIPTION_ID| Required |Provide subscription id here   |
|USE_EXISTING_RESOURCES| Required |If the value is set to "yes", the script will use an existing resources if they are already present in Azure. If it is not set to true, the script will fail for Resource Group if there is already an existing resource group with the given name in Azure. For other resources, it will create new resources by appending a random number to the given names|
|RESOURCE_GROUP| Required |Name of a resource group which will be created for the app.    |
|LOCATION| Required |Azure Data Centre location for the resource group and resources. Exp. East US   |
|IOTHUB_NAME| Required |Name of the IoT Hub   |
|DEVICE_NAME| Required |Name of the IoT Edge device on IoT Hub   |
|DEPLOYMENT_NAME| Required |Name of the deployment on the Edge device in IoT Hub. Please note that this should be unique for each deployment|
|USE_INTERACTIVE_LOGIN_FOR_AZURE| Required |If value is set to "true", the script will prompt the user for authentication. If it is not set to true, non-interactive login with service principal will be used|
|SP_APP_ID| Optional |ID of the service principal which will be used to log into Azure. This is required if USE_INTERACTIVE_LOGIN_FOR_AZURE is not set to "true"   |
|SP_APP_PWD| Optional |Secret of the service principal which will be used to log into Azure. This is required if USE_INTERACTIVE_LOGIN_FOR_AZURE is not set to "true"   |
|CREATE_AZURE_MONITOR| Required |If the value is set to "true", a new service principal with monitor role on the IoT hub will be created and the values will be set in the deployment template file |
|AZURE_MONITOR_SP_NAME| Optional |Service Principal name of the Azure Monitor service  |
|IS_THE_SCRIPT_RUNNING_FROM_EDGE_DEVICE| Required |Value should be "true" if the script is running on the Edge device|
|EDGE_DEVICE_IP| Optional |IP of the Edge device. This is required if IS_THE_SCRIPT_RUNNING_FROM_EDGE_DEVICE is not set to "true"  |
|EDGE_DEVICE_USERNAME| Optional |Username of an account on Edge device, this account should have access to modify files on Edge device. This is required if IS_THE_SCRIPT_RUNNING_FROM_EDGE_DEVICE is not set to "true"   |
|EDGE_DEVICE_PASSWORD| Optional |Password for the account on Edge device. This is required if IS_THE_SCRIPT_RUNNING_FROM_EDGE_DEVICE is not set to "true"  |
|MANIFEST_TEMPLATE_NAME| Optional |Name of the template manifest file   |
|MANIFEST_ENVIRONMENT_VARIABLES_FILENAME| Optional |Name of the environment variable file containing values/secret   |
|PRE_GENERATED_MANIFEST_FILENAME| Optional |Name of the pre-generated manifest file. If this is not empty, this file will be used for deployment on Edge device. In case this is empty, the manifest template and environment files will be used to generate a manifest file.	|
|CUSTOM_VIDEO_SOURCE| Optional |Custom video that user can provide for the Edge device   |
|DEFAULT_ROUTE_ROUTING_CONDITION| Required |Routing condition for inbuilt IoT Hub endpoint 'events'. Special characters must be escaped in the string   |
|PUSH_RESULTS_TO_ADLS| Required |If the value is set to "true", telemetry data will be pushed to ADLS	|
|STORAGE_ACCOUNT_NAME| Optional |Storage account name for ADLS. This is required if PUSH_RESULTS_TO_ADLS is set to "true"	|
|BLOBCONTAINER_NAME| Optional |Container name for ADLS. This is required if PUSH_RESULTS_TO_ADLS is set to "true"	|
|ADLS_ENDPOINT_NAME| Optional |Custom Data Lake Endpoint for Edge device in IoT Hub. This is required if PUSH_RESULTS_TO_ADLS is set to "true"	|
|IOTHUB_ADLS_ROUTENAME| Optional |Route name for the data to be pushed to ADLS in IoT Hub. This is required if PUSH_RESULTS_TO_ADLS is set to "true"	|
|ADLS_ROUTING_CONDITION| Optional |Condition for filtering the routing data for adls route. Special characters must be escaped in the string |
|PUSH_RESULTS_TO_EVENT_HUB| Required |If the value is set to "true", the script will set up required resources to enable data push to event hub|
|EVENTHUB_NAMESPACE| Optional |Name of the event hub namespace. This is required if PUSH_RESULTS_TO_EVENT_HUB is set to "true" |
|EVENTHUB_NAME| Optional |Name of the event hub. This is required if PUSH_RESULTS_TO_EVENT_HUB is set to "true" |
|EVENTHUB_ROUTENAME| Optional |Name of the route that will push data to event hub through event hub custom endpoint. This is required if PUSH_RESULTS_TO_EVENT_HUB is set to "true"|
|EVENTHUB_ENDPOINT_NAME| Optional | Name of the custom endpoint that will be created to push data to Event Hub. This is required if PUSH_RESULTS_TO_EVENT_HUB is set to "true"|
|EVENTHUB_ROUTING_CONDITION| Optional | Condition for filtering the routing data for event hub route. Special characters must be escaped in the string|
|SETUP_FRONTEND_APP| Optional | Set it to true to deploy front end application on Azure App Service to monitor the feed from Edge Device|
|APP_SERVICE_PLAN_NAME| Optional | App Service Plan name for the front end application. Required if SETUP_FRONTEND_APP is set to true|
|APP_SERVICE_PLAN_SKU| Optional | Sku for the App Service Plan of the front end application. Required if SETUP_FRONTEND_APP is set to true|
|WEBAPP_NAME| Optional |Name of the Azure Web App for front end application. Required if SETUP_FRONTEND_APP is set to true|
|PASSWORD_FOR_WEBSITE_LOGIN| Optional | Password for the Azure Web App. Required if SETUP_FRONTEND_APP is set to true|
|WEBAPP_DEPLOYMENT_ZIP| Optional | Deployment zip for the Azure Web App. If this is not provided, front end application repositories must be present in parent directory of setup script|

### Run Setup Script To Deploy Solution
After all values have been specified in the variables.template file, proceeed to running the [setup.sh](setup.sh) script which automates deployment and setup of required resources for Person Tracking App.

```sh
chmod +x ./setup.sh
./setup.sh
```


## The following are the resource naming rules for Azure resources used.

|Entity |Type |Length |Casing |Valid Characters |
|---|---|---|---|---|
|RESOURCE_GROUP |Resource Group |1-90 |Case insensitive |Alphanumeric, underscore, and hyphen |
|IOTHUB_NAME |Iot hub name |3-50 |Case insensitive  |Alphanumerics and hyphens. Can't end with hyphen |
|DEVICE_NAME |Device Name |1-15 |Case insensitive |Alphanumeric, underscore, and hyphen |
|STORAGE_ACCOUNT_NAME |Storage Account Name |3-24 |Lower case |Alphanumeric |
|BLOBCONTAINER_NAME |Blob container name |3-63 |Lower case |Alphanumeric and hyphen .Can't use consecutive hyphens |
|DEPLOYMENT_NAME |Deployment name |1-64 |Case insensitive |Alphanumerics, underscores, parentheses, hyphens, and periods. |
|EVENTHUB_NAMESPACE |Eventhub namespace |1-50 |Case insensitive |Alphanumerics, periods, hyphens and underscores.Start and end with letter or number. |
|EVENTHUB_NAME |Eventhub name |1-50 |Case insensitive |Alphanumerics, periods, hyphens and underscores.Start and end with letter or number. |
|EVENTHUB_ENDPOINT_NAME |Eventhub endpoint name |1-50 |Case insensitive |Alphanumerics, hyphens, periods, and underscores |