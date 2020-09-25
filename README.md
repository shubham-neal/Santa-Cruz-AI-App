# Unified Edge Scenarios Deployment Guide

This document serves to walk through the end-user deployment and onboarding experience for the open source people detection on Azure Mariner VM. 


## Deploy Solution
Two deployment scenarios are supported. 

**Supported Deployment Scenarios:**
- End-to-end Deployment (Developer / dogfooding experience)
- Edge Module Deployment (End-user-unboxing experience)

### Scenario 1: End-to-end Deployment (Developer / dogfooding experience)

- Creates a new resource group, IoT Hub, Edge Device, and links physical edge device to IoT Hub
- Customizes the deployment for your environment
- Deploys the IoT Edge manifest to the edge device

### Scenario 2: Edge Module Deployment (End-user unboxing experience)

- Uses existing resource groups, IoT Hub, and Edge Device that has already been onboarded
- Customizes the deployment for your environment
- Deploys the IoT Edge manifest to the edge device


Two deployment methods are supported.

**Supported Deployment Methods:**
- ARM Template Deployment
- CloudShell Deployment

### **Method 1: ARM Template Deployment**

  [Prerequisites](docs/arm_template-prerequisites.md#arm-template-deployment-prerequisites) for ARM Template Deployment. 
  
  ### Scenario 1: End-to-end Deployment (Developer / dogfooding experience)
  - **Deployment Steps**
    
    
    Step 1: Create a custom template deployment using this button 
    
    [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://ms.portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Funifiededgescenarios.blob.core.windows.net%2Farm-template%2Fazuredeploy-latest.json)

    Step 2: Provide the following parameters value to deploy:

    **Mandatory Variables**
    |Name | Description  |
    |---|---|
    |Region|Location for resources to be deployed|
    |Resource Group Iot| Resource group name for IoT Hub, Storage Accounts and Web App|
    |Resource Group Device| Resource group name for Mariner VM|

    **Optional Variables**
    |Name | Description  |
    |---|---|
    |Module Runtime| Runtime for Detector module on Edge Device. Default value is 'CPU'. Set it to 'CPU' to use CPU to run detector module. If the Edge Device has Nvidia GPU, set it to 'NVIDIA' to use GPU to run detector module or to use movidius set it to 'MOVIDIUS'.|
    |Device Architecture| Specify the architecture of the Edge Device. Default value is 'X86'. Currently supported values are 'X86' and 'ARM64'.|
    |Password| Password to access the Web App. Default value is empty|
    |Use Existing Edge Device|Whether you want to create the edge device or skip this part and use existing resources. NOTE: In scenario of End-to-end Deployment, set the value to 'NO'|

    Step 3: Click on Review+Create to validate and start the deployment.

    Step 4: After deployment completes, you can find the Web App Url in the output section of deployment.


  ### Scenario 2: Edge Module Deployment (End-user unboxing experience)
  - **Deployment Steps**


    Step 1: Create a custom template deployment using this button

    [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://ms.portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Funifiededgescenarios.blob.core.windows.net%2Farm-template%2Fazuredeploy-latest.json) 
    
    Step 2: Provide the following parameters value to deploy:

    **Mandatory Variables**
    |Name | Description  |
    |---|---|
    |Region|Location for resources to be deployed|
    |Resource Group Iot| Resource group name for IoT Hub, Storage Accounts and Web App|
    |Use Existing Edge Device|Whether you want to create the edge device or skip this part and use existing resources. NOTE: In scenario of Edge Module Deployment, set the value to 'YES' and provide the Iot Hub & Device Name parameters as well|
    |Existing Iot Hub Name|the name of existing iot hub to be used.|
    |Existing Device Name|the name of existing device to be used.|

    **Optional Variables**
    |Name | Description  |
    |---|---|
    |Password| Password to access the web app. Default value is empty|

    Step 3: Click on Review+Create to validate and start the deployment.

    Step 4: After deployment completes, you can find the WebApp Url in the output section of deployment.


### **Method 2: CloudShell Deployment**

[Prerequisites](docs/cloudshell-deployment-steps.md#prerequisites) for CloudShell Deployment.

  ### Scenario 1: End-to-end Deployment (Developer / dogfooding experience)
  - **Deployment Steps for Standard Deployment**


    Step 1: Use the following command to download the shell script to your local machine
      
    ```sh
    wget "https://unifiededgescenarios.blob.core.windows.net/people-detection/cloudshell-deployment.sh?sp=r&st=2020-09-03T16:01:57Z&se=2022-09-04T00:01:57Z&spr=https&sv=2019-12-12&sr=b&sig=m%2F0dNbnwsnz1081pU5l2YC3XUclrTJ5ku7vLK4WsOIY%3D" -O cloudshell-deployment.sh
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

  - **Deployment Steps for Custom Deployment**
        
        
    You can follow the detailed step by step [instructions here](docs/cloudshell-deployment-steps.md#scenario-1:-end-to-end-deployment-(developer-/-dogfooding-experience))

  ### Scenario 2: Edge Module Deployment (End-user unboxing experience)
  - **Deployment Steps for Standard Deployment**
    
    
    Step 1: Use the following command to download deployment bundle zip to your local machine and inflate it
      
    ```sh
    wget "https://unifiededgescenarios.blob.core.windows.net/people-detection/cloudshell-deployment.sh?sp=r&st=2020-09-03T16:01:57Z&se=2022-09-04T00:01:57Z&spr=https&sv=2019-12-12&sr=b&sig=m%2F0dNbnwsnz1081pU5l2YC3XUclrTJ5ku7vLK4WsOIY%3D" -O cloudshell-deployment.sh
    ```

    Step 2: Add executable bit to cloudshell-deployment script and execute it with following parameters as arguments.
    |Name | Description  |
    |---|---|
    |--device-runtime| Runtime for Detector module on Edge Device. Set it to 'CPU' to use CPU to run detector module. If the Edge Device has Nvidia GPU, set it to 'NVIDIA' to use GPU to run detector module or to use movidius set it to 'MOVIDIUS'.|
    |--device-architecture| Specify the architecture of the Edge Device. Currently supported values are 'X86' and 'ARM64'.|
    |--website-password| Password to access the Web App|
    |--rg-iot| Resource group IoT Hub, Storage Accounts and Web App|
    |--iothub-name| Name of the existing IoT Hub. This IoT Hub must have a existing IoT Edge device setup in it. This IoT Hub must be present in rg-iot resource group.|
    |--device-name| Name of the IoT Edge device in the IoT Hub.|

    ```sh
    chmod +x cloudshell-deployment.sh
    ./cloudshell-deployment.sh --device-runtime "CPU" --website-password "Password" --rg-iot "iotresourcegroup" --device-architecture "X86" --iot-name "azureeyeiot" --device-name "azureeye"
    ```

  - **Deployment Steps for Custom Deployment**
       
       
    You can follow the detailed step by step [instructions here](docs/cloudshell-deployment-steps.md#scenario-2:-edge-module-deployment-(end-user-unboxing-experience))  