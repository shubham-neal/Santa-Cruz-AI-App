# Unified Edge Scenarios Deployment Guide

This document serves to walk through the end-user deployment and onboarding experience for the open source people detection on Azure Mariner VM. 

## Prerequisites

- The machine you run the below instructions from must be a linux-based device. The instructions below have been tested on Azure CloudShell.
- The user or service principal running the scripts should have access to create resources in the given subscription in Azure
- User running the script should have access to create directories and files on the machine

## Install Package Dependencies

- The machine should have Azure CLI installed on it. The other required packages can be installed from the scripts if they are not present. \
You can follow the [instruction here](docs/packages-installation-steps.md) if you need to install the required packaged manually.  

## Deploy Solution
Two deployment scenarios are supported. 

**Supported Deployment Scenarios:**
- End-to-end deployment (Developer / dogfooding experience)
- Edge Module Deployment (End-user-unboxing experience)


### Scenario #1: End-to-end deployment (Developer / dogfooding experience)

- Creates a new resource group, IoT Hub, Edge Device, and links physical edge device to IoT Hub
- Customizes the deployment for your environment
- Deploys the IoT Edge manifest to the edge device
  

  **Deployment Steps for Standard Deployment**
      

  Step 1: Use the following command to download the shell script to your local machine
     
  ```sh
  wget "https://unifiededgescenarios.blob.core.windows.net/cloudshell-script/cloudshell-deployment.sh" -O cloudshell-deployment.sh
  ```
    

  Step 2: Add executable bit to cloudshell-deployment script and execute it with following parameters as arguments.  
  |Name | Description  |
  |---|---|
  |--create-iothub| Specify if you do not have an existing IoT Edge Device setup on IoT Hub.|
  |--device-runtime| Runtime for Detector module on Edge Device. Set it to 'CPU' to use CPU to run detector module. If the Edge Device has Nvidia GPU, set it to 'NVIDIA' to use GPU to run detector module or to use movidius set it to 'MOVIDIUS'.|
  |--device-architecture| Specify the architecture of the Edge Device. Currently supported values are 'X86' and 'ARM64'.|
  |--website-password| Password to access the web app|
  |--rg-iot| Resource group name for IoT Hub, Storage Accounts and Web App|
  |--rg-vm| Resource group name for Mariner VM|

  ```sh
  chmod +x cloudshell-deployment.sh
  ./cloudshell-deployment.sh --create-iothub --device-runtime "CPU" --website-password "Password" --rg-iot "iotresourcegroup" --device-architecture "X86" --rg-vm "vmresourcegroup"
  ```

  **Deployment Steps for Custom Deployment**
      

  Step 1: Use the following command to download deployment bundle zip to your local machine and inflate it
    
  ```sh
  wget "https://unifiededgescenarios.blob.core.windows.net/cloudshell-script/cloudshell-deployment.sh" -O cloudshell-deployment.sh
  ```
    
  Step 2: Add executable bit to cloudshell-deployment script and execute it with --custom-deployment argument. Switch to deployment-bundle-latest directory.
  ```sh
  chmod +x cloudshell-deployment.sh
  ./cloudshell-deployment.sh --custom-deployment
  cd deployment-bundle-latest
  ```

  Step 3: Provide the variables in variables.template file in deployment-bundle-latest directory.
  - Add values in [variables.template](variables.template) file. Specify values for all the mandatory variables in [Configuring Variable Template Files](#configuring-variable-template-files) and specify values for variables RESOURCE_GROUP_DEVICE variable.


  Step 4: Run eye-vm-setup.sh script
  - Run [eye-vm-setup.sh](eye-vm-setup.sh) script

  ```sh
  sudo ./eye-vm-setup.sh
  ```

  Step 5: Setup IoT Hub and Edge Device   
  - Run [deploy-iot.sh](deploy-iot.sh) script

  ```sh
  sudo ./deploy-iot.sh
  ```


  Step 6: Setup a Front End app to visualize the results
  - Run [frontend-setup.sh](frontend-setup.sh) script

  ```sh
  sudo ./frontend-setup.sh
  ```


### Scenario 2: Edge Module Deployment (End-user unboxing experience)

- Uses existing resource groups, IoT Hub, and Edge Device that has already been onboarded
- Customizes the deployment for your environment
- Deploys the IoT Edge manifest to the edge device
  

  **Deployment Steps for Standard Deployment**
    
    
  Step 1: Use the following command to download deployment bundle zip to your local machine and inflate it
    
  ```sh
  wget "https://unifiededgescenarios.blob.core.windows.net/cloudshell-script/cloudshell-deployment.sh" -O cloudshell-deployment.sh
  ```

  Step 2: Add executable bit to cloudshell-deployment script and execute it with following parameters as arguments.
  |Name | Description  |
  |---|---|
  |--device-runtime| Runtime for Detector module on Edge Device. Set it to 'CPU' to use CPU to run detector module. If the Edge Device has Nvidia GPU, set it to 'NVIDIA' to use GPU to run detector module or to use movidius set it to 'MOVIDIUS'.|
  |--device-architecture| Specify the architecture of the Edge Device. Currently supported values are 'X86' and 'ARM64'.|
  |--website-password| Password to access the web app|
  |--rg-iot| Resource group IoT Hub, Storage Accounts and Web App|
  |--iothub-name| Name of the existing IoT Hub. This IoT Hub must have a existing IoT Edge device setup in it. This IoT Hub must be present in rg-iot resource group.|
  |--device-name| Name of the IoT Edge device in the IoT Hub.|

  ```sh
  chmod +x cloudshell-deployment.sh
  ./cloudshell-deployment.sh --device-runtime "CPU" --website-password "Password" --rg-iot "iotresourcegroup" --device-architecture "X86" --iot-name "azureeyeiot" --device-name "azureeye"
  ```


  **Deployment Steps for Custom Deployment**
      

  Step 1: Use the following command to download deployment bundle zip to your local machine and inflate it
    
  ```sh
  wget "https://unifiededgescenarios.blob.core.windows.net/cloudshell-script/cloudshell-deployment.sh" -O cloudshell-deployment.sh
  ```

  Step 2: Add executable bit to cloudshell-deployment script and execute it with --custom-deployment argument. Switch to deployment-bundle-latest directory.

  ```sh
  chmod +x cloudshell-deployment.sh
  ./cloudshell-deployment.sh --custom-deployment
  cd deployment-bundle-latest
  ```

  Step 3: Update values in variables.template file.
  - Add values in [variables.template](variables.template) file. Specify values for all the mandatory variables in [Configuring Variable Template Files](#configuring-variable-template-files) and specify values for variables IOTHUB_NAME, DEVICE_NAME variables.


  Step 4: Setup the IoT Hub and Edge Device     
  - Run [deploy-iot.sh](deploy-iot.sh) script

  ```sh
  sudo ./deploy-iot.sh
  ```


  Step 5: Setup a Front End app to visualize the results 
  - Run [frontend-setup.sh](frontend-setup.sh) script

  ```sh
  sudo ./frontend-setup.sh
  ```



### Configuring Variable Template Files
  
Refer to the following list for variables in the variables.template file.

**Mandatory Variables**
  

Section 1: General configuration which applies to all components

|Name | Description  |
|---|---|
|DETECTOR_MODULE_RUNTIME| Runtime for Detector module on Edge Device. Set it to 'CPU' to use CPU to run detector module. If the Edge Device has Nvidia GPU, set it to 'NVIDIA' to use GPU to run detector module or to use movidius set it to 'MOVIDIUS'.|
|EDGE_DEVICE_ARCHITECTURE| Specify the architecture of the Edge Device. Currently supported values are 'X86' and 'ARM64'.|

Section 3: IoT Hub + Storage configuration to route and host the AI output

|Name | Description  |
|---|---|
|RESOURCE_GROUP_IOT| Name of a resource group which will contain IoT Hub, Storage Account and Web App.    |

Section 4: Vizualization UX application

|Name | Description  |
|---|---|
|PASSWORD_FOR_WEBSITE_LOGIN| Password for the Azure Web App|



  
**Optional Variables**
  


Section 1: General configuration which applies to all components

|Name | Description  |
|---|---|
|TENANT_ID| Provide tenant id of your organization here. This is not required for Azure Cloud Shell environment. Script will use existing login of Azure Cloud Shell.   |
|SUBSCRIPTION_ID| Provide subscription id here. If Empty, Script will use first subscription id from the list of subscriptions which user has access. |
|LOCATION| Azure Data Centre location for the resource group and resources. Default value is 'west us 2' |


Section 2: Virtualized Eye VM in the public cloud

|Name | Description  |
|---|---|
|RESOURCE_GROUP_DEVICE| Name of a resource group which will contain mariner VM.    |
|DISK_NAME   | Name for the managed disk that will be created. Default value is 'mariner'         |
|VM_NAME  | Name of the VM that will be created. Default value is 'marinervm' |


Section 3: IoT Hub + Storage configuration to route and host the AI output

|Name | Description  |
|---|---|
|IOTHUB_NAME| Name of the IoT Hub   |
|DEVICE_NAME| Name of the IoT Edge device on IoT Hub   |
|STORAGE_ACCOUNT_NAME| Storage account name for ADLS. |


Section 4: Vizualization UX application

|Name | Description  |
|---|---|
|APP_SERVICE_PLAN_NAME|  App Service Plan name for the front end application|
|WEBAPP_NAME| Name of the Azure Web App for front end application|


The following sections are for variables which have a default value set in variables.template file.

Section 1: General configurations 

|Name | Description  |
|---|---|
|USE_INTERACTIVE_LOGIN_FOR_AZURE| If value is set to "true", the script will prompt the user for authentication. If it is not set to true, non-interactive login with service principal will be used. This is not required for Azure Cloud Shell environment. Script will use existing login of Azure Cloud Shell.|
|SP_APP_ID| ID of the service principal which will be used to log into Azure. This is required if USE_INTERACTIVE_LOGIN_FOR_AZURE is not set to "true" and current environment is not Azure Cloud Shell. Script will use existing login of Azure Cloud Shell.   |
|SP_APP_PWD| Secret of the service principal which will be used to log into Azure. This is required if USE_INTERACTIVE_LOGIN_FOR_AZURE is not set to "true" and current environment is not Azure Cloud Shell. Script will use existing login of Azure Cloud Shell.   |
|USE_EXISTING_RESOURCES| If the value is set to "yes", the script will use an existing resources if they are already present in Azure. If it is not set to true, the script will fail for Resource Group if there is already an existing resource group with the given name in Azure. For other resources, it will create new resources by appending a random number to the given names|
|INSTALL_REQUIRED_PACKAGES| Whether or not to install required packaged dependencies. This is useful if you are not running the setup from Azure Cloud Shell. Set to "true" to install the dependencies or "false" to skip installation. |

Section 2: Virtualized Eye VM

|Name | Description  |
|---|---|
|STORAGE_TYPE | Underlying storage SKU. Default value is 'Premium_LRS'  |
|VM_SIZE  | The VM size to be created. Default value is 'Standard_DS2_v2'  |

Section 3: IoT Hub + Storage configuration to route and host the AI output

|Name | Description  |
|---|---|
|MANIFEST_TEMPLATE_NAME| Name of the template manifest file   |
|MANIFEST_ENVIRONMENT_VARIABLES_FILENAME| Name of the environment variable file containing values/secret   |
|DEPLOYMENT_NAME| Name of the deployment on the Edge device in IoT Hub. Please note that this should be unique for each deployment|
|CUSTOM_VIDEO_SOURCE| Custom video that user can provide for the Edge device   |

Section 4: Vizualization UX application

|Name | Description  |
|---|---|
|APP_SERVICE_PLAN_SKU| Sku for the App Service Plan of the front end application|
