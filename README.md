# Open Source People Counting AI Application


Press this button to deploy the people counting application to your Santa Cruz AI device:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://ms.portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Funifiededgescenarios.blob.core.windows.net%2Farm-template%2Fazure-eye%2Flatest%2Fazuredeploy-eye.json)


## Legacy Deployment





Press this button to deploy the people counting application to virtualized environment in Azure Public Cloud.

[Read this](docs/virtualized-environment-setup.md) for instructions on how to use Legacy Deployment method.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Funifiededgescenarios.blob.core.windows.net%2Farm-template%2F20201005.6%2Fazuredeploy-20201005.6.json)



### Overview

This is an open source Santa Cruz AI application providing edge-based people counting with user-defined zone entry/exit events. Video and AI output from the on-prem edge device is egressed to Azure Data Lake using Azure Media Service, with the user interface running as an Azure Website. AI inferencing is provided by Azure Eye for people detection:


![People Detector](docs/images/People-Detector-AI.gif)


###
This application can execute with a physical Santa Cruz AI Devkit.


## Physical hardware app topology
![People Detector](docs/images/AI-App-Topology.PNG)


# Installation details
This reference open source application showcases best practices for AI security, privacy and compliance.  It is intended to be immediately useful for anyone to use with their Santa Cruz AI device. Deployment starts with this button:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://ms.portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Funifiededgescenarios.blob.core.windows.net%2Farm-template%2Fazure-eye%2Flatest%2Fazuredeploy-eye.json)
#

This will redirect you to the Azure portal with this deployment page:

![People Detector](docs/images/Custom-Deployment-Eye.JPG)
#

To deploy an emulation environment in the cloud, please enter the following parameters:

* __Resource Group Device__ = Name of the resource group which host your Azure IoT Hub connected to Azure Eye device
* __Resource Group AMS__ = Unique name of a new resource group to host Azure Media Service, Azure Data Lake and Front End application.
* __Existing IoT Hub Name__ = Name of a the IoT Hub that is connected to Azure Eye device.
* __Existing Device Name__ = Name of the IoT Edge device in IoT Hub which is connected to Azure Eye device.
* __Service Principal Id__ = Id of an existing Service Principal which will be used in Azure Media Service.
* __Service Principal Object Id__ = Object Id of an existing Service Principal which will be used in Azure Media Service.
* __Service Principal Secret__ = Secret of an existing Service Principal which will be used in Azure Media Service.
* __Password__ = A password to protect access to the web app which visualizes your output. A best practice is to assign a password to prevent others on the internet from seeing the testing output of your Santa Cruz AI device.

Once deployment is complete, you can launch the web application by navigating to the `Resource Group AMS` name selected above. You will see an Azure Web Services deployment which starts with `ues-eyeapp` followed by 4 random characters. Select this app, then chose the `Browse` button in the top left:

![Web Application](docs/images/Web-App-Launch.PNG)

Once the application loads, you will need to enter the password you entered at deployment time. The password is cached for subsequent visits to the same application.

# People Counting in a Zone

You can create a poloygon region in the camera frame to count the number of people in the zone.  Metrics are displayed at the bottom showing total people in the frame vs. people in the zone.  To create a zone, click anywhere on the video window to establish the first corner of your polygon. Clicking 4 times will create a 4-sided polygon. People identified in the zone are shown with a yellow highlight.  Press the `Clear` button in the lower right to clear your zone definition.

#

### Application Installation Permissions
To install this reference application you must have Owner level access to the target subscription.  This deployment will create resources within the following Azure namespaces. These resource providers must be enabled on the subscription.

* Microsoft.Devices
* Microsoft.Authorization
* Microsoft.ContainerInstance
* Microsoft.ManagedIdentity
* Microsoft.Web
* Microsoft.Storage
* Microsoft.Resources
* Microsoft.Media
