# Unified Edge Scenarios Deployment Guide

This document serves to walk through the end-user deployment and onboarding experience for the open source people detection on Azure Brainbox. 


## Mariner OS VM Creation
You may wish to create a VM in Azure to emulate the edge device hardware for testing purposes. To create a VM with the custom OS image, please follow the [instructions here](docs/setup-brainbox.md).

## Prerequisites

- The machine you run the below instructions from must be a linux-based device. The instructions below have been tested on Ubuntu 18.04 LTS.
- The user or service principal running the scripts should have access to create resources in the given subscription in Azure
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
    - Add values in [variables.template](variables.template) file. You can refer to the [Configuring Variable Template Files](###Configuring-Variable-Template-Files) section to see how to specify values for the variables.


    Step 2: Setup the IoT Hub and Edge Device   
    - Run [setup.sh](setup.sh) script

    ```sh
    chmod +x setup.sh
    ./setup.sh
    ```


    Step 3: Setup a Front End app to visualize the results
    - Add values in [frontend-variables.template](./frontend-variables.template)
      You can refer to the [Configuring Variable Template Files](###Configuring-Variable-Template-Files) section to see how to specify values for the variables.
    - Run [frontend-setup.sh](frontend-setup.sh) script

    ```sh
    chmod +x frontend-setup.sh
    ./frontend-setup.sh
    ```


### Scenario 2: Edge Module Deployment (End-user unboxing experience)

- Uses an existing resource group, IoT Hub, and Edge Device that has already been onboarded
- Customizes the deployment for your environment
- Deploys the IoT Edge manifest to the edge device

  **Deployment Steps:**

    Step 1: Provide required inputs to run the setup scripts
    - Add values in [variables.template](variables.template) file. You can refer to the [Configuring Variable Template Files](###Configuring-Variable-Template-Files) section to see how to specify values for the variables.  

    
    Step 2: Setup the IoT Hub and Edge Device     
    - Run [deploy-manifest.sh](deploy-manifest.sh) script

    ```sh
    ./deploy-manifest.sh
    ```


    Step 3: Setup a Front End app to visualize the results
    - Add values in [frontend-variables.template](frontend-variables.template) file. You can refer to [Configuring Variable Template Files](###Configuring-Variable-Template-Files) section to see how to specify values for the variables. 
    - Run [frontend-setup.sh](frontend-setup.sh) script

    ```sh
    ./frontend-setup.sh
    ```


### Configuring Variable Template Files
  
Refer to the following list for variables in the variables.template file.
  
|Name | Required? |Description  |
|---|---|---|
|USE_INTERACTIVE_LOGIN_FOR_AZURE| Required |If value is set to "true", the script will prompt the user for authentication. If it is not set to true, non-interactive login with service principal will be used|
|SP_APP_ID| Optional |ID of the service principal which will be used to log into Azure. This is required if USE_INTERACTIVE_LOGIN_FOR_AZURE is not set to "true"   |
|SP_APP_PWD| Optional |Secret of the service principal which will be used to log into Azure. This is required if USE_INTERACTIVE_LOGIN_FOR_AZURE is not set to "true"   |
|TENANT_ID| Required |Provide tenant id of your organization here   |
|SUBSCRIPTION_ID| Required |Provide subscription id here   |
|USE_EXISTING_RESOURCES| Required |If the value is set to "yes", the script will use an existing resources if they are already present in Azure. If it is not set to true, the script will fail for Resource Group if there is already an existing resource group with the given name in Azure. For other resources, it will create new resources by appending a random number to the given names|
|RESOURCE_GROUP| Required |Name of a resource group which will be created for the app.    |
|LOCATION| Required |Azure Data Centre location for the resource group and resources. |
|INSTALL_REQUIRED_PACKAGES| Required |Whether or not to install required packaged dependencies. This is useful if you are not running the setup from Azure Cloud Shell. Set to "true" to install the dependencies or "false" to skip installation. |
|IOTHUB_NAME| Required |Name of the IoT Hub   |
|DEVICE_NAME| Required |Name of the IoT Edge device on IoT Hub   |
|STORAGE_ACCOUNT_NAME| Required |Storage account name for ADLS. |
|EDGE_DEVICE_IP| Required |IP of the Edge device.  |
|EDGE_DEVICE_USERNAME| Required |Username of an account on Edge device, this account should have access to modify files on Edge device.    |
|EDGE_DEVICE_PASSWORD| Required |Password for the account on Edge device|
|DETECTOR_MODULE_RUNTIME| Required |Runtime for Detector module on Edge Device. Set it to 'runc' to use CPU to run detector module. If the Edge Device has Nvidia GPU, set it to 'nvidia' to use GPU to run detector module|
|EDGE_DEVICE_ARCHITECTURE| Required |Specify the architecture of the Edge Device. Currently supported values are amd64 and arm64v8.|
|MANIFEST_TEMPLATE_NAME| Required |Name of the template manifest file   |
|MANIFEST_ENVIRONMENT_VARIABLES_FILENAME| Required |Name of the environment variable file containing values/secret   |
|DEPLOYMENT_NAME| Required |Name of the deployment on the Edge device in IoT Hub. Please note that this should be unique for each deployment|
|CUSTOM_VIDEO_SOURCE| Optional |Custom video that user can provide for the Edge device   |

  
Refer to the following list for variables in the frontend-variables.template file.

|Name | Required? |Description  |
|---|---|---|
|APP_SERVICE_PLAN_NAME| Required | App Service Plan name for the front end application|
|APP_SERVICE_PLAN_SKU| Required | Sku for the App Service Plan of the front end application|
|WEBAPP_NAME| Required |Name of the Azure Web App for front end application|
|PASSWORD_FOR_WEBSITE_LOGIN| Required | Password for the Azure Web App|



### Resource Naming Rules in Azure

The following are the resource naming rules for Azure resources which are used in the script. Follow these rules while specifying values in variable files. 
  

|Entity |Type |Length |Casing |Valid Characters |
|---|---|---|---|---|
|RESOURCE_GROUP |Resource Group |1-90 |No casing restriction |Alphanumeric, underscore, and hyphens |
|IOTHUB_NAME |Iot Hub name |3-50 |No casing restriction  |Alphanumerics and hyphens. Can't end with hyphen |
|DEVICE_NAME |Device Name |1-15 |No casing restriction |Alphanumeric, underscore, and hyphen |
|STORAGE_ACCOUNT_NAME |Storage Account Name |3-24 |Lower case only |Alphanumeric |
|DEPLOYMENT_NAME |Deployment name |1-64 |No casing restriction |Alphanumerics, underscores, parentheses, hyphens, and periods. |
|APP_SERVICE_PLAN_NAME |ServerFarm |1-40 |No casing restriction |Alphanumerics and hyphens |
|WEBAPP_NAME |sites |2-60 |No casing restriction |Contains alphanumerics and hyphens. Can't start or end with hyphen. |