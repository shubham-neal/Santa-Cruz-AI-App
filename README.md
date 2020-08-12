# Unified Edge Scenarios Deployment Guide

This document serves to walk through the end-user deployment and onboarding experience for the open source people detection on Azure Mariner VM. 

## Prerequisites

- The machine you run the below instructions from must be a linux-based device. The instructions below have been tested on Ubuntu 18.04 LTS.
- The user or service principal running the scripts should have access to create resources in the given subscription in Azure
- User running the script should have access to create directories and files on the machine
- Set values in the [variables.template](variables.template) file before running the script

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


  **Deployment Steps:**

    Step 1: Provide required inputs to run the setup scripts
    - Add values in [variables.template](variables.template) file. You can refer to the [Configuring Variable Template Files](#configuring-variable-template-files) section to see how to specify values for the variables.


    Step 2: Create Mariner VM, IoT Hub and Edge Device   
    - Run [eye-vm-setup.sh](eye-vm-setup.sh) script

    ```sh
    chmod +x eye-vm-setup.sh
    sudo ./eye-vm-setup.sh
    ```

    Step 3: Setup IoT Hub and Edge Device   
    - Run [deploy-iot.sh](deploy-iot.sh) script

    ```sh
    chmod +x deploy-iot.sh
    sudo ./deploy-iot.sh
    ```


    Step 4: Setup a Front End app to visualize the results
    - Run [frontend-setup.sh](frontend-setup.sh) script

    ```sh
    chmod +x frontend-setup.sh
    sudo ./frontend-setup.sh
    ```


### Scenario 2: Edge Module Deployment (End-user unboxing experience)

- Uses existing resource groups, IoT Hub, and Edge Device that has already been onboarded
- Customizes the deployment for your environment
- Deploys the IoT Edge manifest to the edge device

  **Deployment Steps:**

    Step 1: Provide required inputs to run the setup scripts
    - Add values in [variables.template](variables.template) file. You can refer to the [Configuring Variable Template Files](#configuring-variable-template-files) section to see how to specify values for the variables.  

    
    Step 2: Setup the IoT Hub and Edge Device     
    - Run [deploy-iot.sh](deploy-iot.sh) script

    ```sh
    chmod +x deploy-iot.sh
    sudo ./deploy-iot.sh
    ```


    Step 3: Setup a Front End app to visualize the results 
    - Run [frontend-setup.sh](frontend-setup.sh) script

    ```sh
    chmod +x frontend-setup.sh
    sudo ./frontend-setup.sh
    ```


### Configuring Variable Template Files
  
Refer to the following list for variables in the variables.template file.

Section 1: General configuration which applies to all components

|Name | Required? |Description  |
|---|---|---|
|TENANT_ID| Optional |Provide tenant id of your organization here. This is not required for Azure Cloud Shell environment. Script will use existing login of Azure Cloud Shell.   |
|SUBSCRIPTION_ID| Required |Provide subscription id here   |
|LOCATION| Required |Azure Data Centre location for the resource group and resources. |
|DETECTOR_MODULE_RUNTIME| Required |Runtime for Detector module on Edge Device. Set it to 'CPU' to use CPU to run detector module. If the Edge Device has Nvidia GPU, set it to 'NVIDIA' to use GPU to run detector module or to use movidius set it to 'MOVIDIUS'.|
|EDGE_DEVICE_ARCHITECTURE| Required |Specify the architecture of the Edge Device. Currently supported values are 'X86' and 'ARM64'.|


Section 2: Virtualized Eye VM in the public cloud

|Name | Required? |Description  |
|---|---|---|
|RESOURCE_GROUP_DEVICE| Required |Name of a resource group which will contain mariner VM.    |
|DISK_NAME   | Optional |  Name for the managed disk that will be created. Default value is mariner         |
|VM_NAME  | Optional |  Name of the VM that will be created. Default value is marinervm |


Section 3: IoT Hub + Storage configuration to route and host the AI output

|Name | Required? |Description  |
|---|---|---|
|RESOURCE_GROUP_IOT| Required |Name of a resource group which will contain IoT Hub, Storage Account and Web App.    |
|IOTHUB_NAME| Required |Name of the IoT Hub   |
|DEVICE_NAME| Required |Name of the IoT Edge device on IoT Hub   |
|STORAGE_ACCOUNT_NAME| Required |Storage account name for ADLS. |


Section 4: Vizualization UX application

|Name | Required? |Description  |
|---|---|---|
|APP_SERVICE_PLAN_NAME| Required | App Service Plan name for the front end application|
|WEBAPP_NAME| Required |Name of the Azure Web App for front end application|
|PASSWORD_FOR_WEBSITE_LOGIN| Required | Password for the Azure Web App|



### Default configurations

Section 1: General configurations 

|Name | Required? |Description  |
|---|---|---|
|USE_INTERACTIVE_LOGIN_FOR_AZURE| Optional |If value is set to "true", the script will prompt the user for authentication. If it is not set to true, non-interactive login with service principal will be used. This is not required for Azure Cloud Shell environment. Script will use existing login of Azure Cloud Shell.|
|SP_APP_ID| Optional |ID of the service principal which will be used to log into Azure. This is required if USE_INTERACTIVE_LOGIN_FOR_AZURE is not set to "true" and current environment is not Azure Cloud Shell. Script will use existing login of Azure Cloud Shell.   |
|SP_APP_PWD| Optional |Secret of the service principal which will be used to log into Azure. This is required if USE_INTERACTIVE_LOGIN_FOR_AZURE is not set to "true" and current environment is not Azure Cloud Shell. Script will use existing login of Azure Cloud Shell.   |
|USE_EXISTING_RESOURCES| Required |If the value is set to "yes", the script will use an existing resources if they are already present in Azure. If it is not set to true, the script will fail for Resource Group if there is already an existing resource group with the given name in Azure. For other resources, it will create new resources by appending a random number to the given names|
|INSTALL_REQUIRED_PACKAGES| Required |Whether or not to install required packaged dependencies. This is useful if you are not running the setup from Azure Cloud Shell. Set to "true" to install the dependencies or "false" to skip installation. |

Section 2: Virtualized Eye VM

|Name | Required? |Description  |
|---|---|---|
|STORAGE_TYPE | Optional | Underlying storage SKU. Default value is Premium_LRS  |
|VM_SIZE  | Optional |  The VM size to be created. Default value is Standard_DS2_v2  |

Section 3: IoT Hub + Storage configuration to route and host the AI output

|Name | Required? |Description  |
|---|---|---|
|MANIFEST_TEMPLATE_NAME| Required |Name of the template manifest file   |
|MANIFEST_ENVIRONMENT_VARIABLES_FILENAME| Required |Name of the environment variable file containing values/secret   |
|DEPLOYMENT_NAME| Required |Name of the deployment on the Edge device in IoT Hub. Please note that this should be unique for each deployment|
|CUSTOM_VIDEO_SOURCE| Optional |Custom video that user can provide for the Edge device   |

Section 4: Vizualization UX application

|Name | Required? |Description  |
|---|---|---|
|APP_SERVICE_PLAN_SKU| Required | Sku for the App Service Plan of the front end application|


### Resource Naming Rules in Azure

The following are the resource naming rules for Azure resources which are used in the script. Follow these rules while specifying values in variable files. 
  
|Entity |Type |Length |Casing |Valid Characters |
|---|---|---|---|---|
|RESOURCE_GROUP_DEVICE |Resource Group |1-90 |No casing restriction |Alphanumeric, underscore, and hyphens |
|RESOURCE_GROUP_IOT |Resource Group |1-90 |No casing restriction |Alphanumeric, underscore, and hyphens |
|IOTHUB_NAME |Iot Hub name |3-50 |No casing restriction  |Alphanumerics and hyphens. Can't end with hyphen |
|DEVICE_NAME |Device Name |1-15 |No casing restriction |Alphanumeric, underscore, and hyphen |
|STORAGE_ACCOUNT_NAME |Storage Account Name |3-24 |Lower case only |Alphanumeric |
|DEPLOYMENT_NAME |Deployment name |1-64 |No casing restriction |Alphanumerics, underscores, parentheses, hyphens, and periods. |
|APP_SERVICE_PLAN_NAME |ServerFarm |1-40 |No casing restriction |Alphanumerics and hyphens |
|WEBAPP_NAME |sites |2-60 |No casing restriction |Contains alphanumerics and hyphens. Can't start or end with hyphen. |