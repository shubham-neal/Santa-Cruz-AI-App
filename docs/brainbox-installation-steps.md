# Open Source People Counting AI Application


### Overview

This is an open source application providing edge-based people counting with user-defined zone entry/exit events. Video and AI output is egressed to Azure Data Lake, with the user interface running as an Azure Website. AI inferencing is provided by an open source AI model for people detection running on Brainbox device:


![People Detector](images/People-Detector-AI.gif)


###
This application executes against a Brainbox device.



# Installation details
This reference open source application showcases best practices for AI security, privacy and compliance.  It is intended to be immediately useful for anyone to use with their Brainbox device. 


1. Download setup script


	```sh
	 wget "https://unifiededgescenarios.blob.core.windows.net/mariner-deployment/latest/mariner-setup.sh"
	 ```


1. Run the script with following parameters

	```sh
	 chmod +x mariner-setup.sh
	 sudo ./mariner-setup.sh --rg-ams "RESOURCE_GROUP_AMS"
	 ```

    The script will prompt to login to Azure CLI if there is no active Azure CLI login.
    
    The following parameters can be passed to the script:
    
    Mandatory Parameters
    * __rg-ams__ = Resource group name for Azure Media Service, Storage Accounts and Web App

    Optional Parameters

    * __rg-device__ = Resource group name for IoT Hub. If it's not provided, rg-ams is used for IoT Hub
    * __existing-iothub__ = Name of existing IoT Hub. Provide this if Brainbox is already connected to IoT Edge device
    * __existing-device__ = Name of existing IoT Edge device in IoT Hub. Provide this if Brainbox is already connected to IoT Edge device
    * __use-existing-sp__ = Whether to use existing service principal.
    * __sp-id__ = Id of existing service principal
    * __sp-password__ = Secret of existing service principal 
    * __sp-object-id__ = Object id of existing service principal
    * __website-password__ = A password to protect access to the web app which visualizes your output. A best practice is to assign a password to prevent others on the internet from seeing the testing output of your Brainbox device.

Once deployment is complete, you can launch the web application by navigating to the `rg-ams` name selected above. You will see an Azure Web Services deployment which starts with `ues-eyeapp` followed by 4 random digits. Select this app, then chose the `Browse` button in the top left:

![Web Application](images/Web-App-Launch.PNG)

Once the application loads, you will need to enter the password you entered at deployment time. The password is cached for subsequent visits to the same application.

# People Counting in a Zone

You can create a poloygon region in the camera frame to count the number of people in the zone.  Metrics are displayed at the bottom showing total people in the frame vs. people in the zone.  To create a zone, click anywhere on the video window to establish the first corner of your polygon. Clicking 4 times will create a 4-sided polygon. People identified in the zone are shown with a yellow highlight.  Press the `Clear` button in the lower right to clear your zone definition.

#

### Application Installation Permissions
To install this reference application you must have Owner access to the target subscription. This deployment will create resources within the following Azure namespaces. These resource providers must be enabled on the subscription.

* Microsoft.Devices
* Microsoft.Authorization
* Microsoft.Web
* Microsoft.Storage
* Microsoft.Resources
* Microsoft.Media