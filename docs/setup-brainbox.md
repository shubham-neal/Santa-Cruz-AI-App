
## Brainbox VM Creation

Follow these steps to create brainbox VM.

1. Configure following variables in [brainbox-variables.template](/brainbox-variables.template)


	|    Variable Name  | Is it Required? | Description |
	|---------------------|-------------|-------------|
	|    USE_INTERACTIVE_LOGIN   | Required |  Set it to true to use interactive login. If it's not set to true, service principal will be used for login           |
	|    TENANT_ID  | Required |  ID for your tenant |
	|    SP_APP_ID   | Optional |   Client ID of Service Principal for login. Only required if USE_INTERACTIVE_LOGIN is not set to true          |
	|    SP_APP_PWD   | Optional |  Client Secret of Service Principal for login. Only required if USE_INTERACTIVE_Login is not set to true           |
	|    SUBSCRIPTION_ID     | Required | ID for your subscription         |
	|    RESOURCE_GROUP | Required | Resource Group Name or ID          |
	|    LOCATION   | Required |  Azure Region location         |
	|    USE_EXISTING_RESOURCE_GROUP   | Required |  If the value is set to "yes", the script will use an existing resource group or create a new one if it does not exist in the given subscription. If it is not set to true, the script will fail if there is an existing resource group with the given name in Azure.          |
	|    INSTALL_REQUIRED_PACKAGES   | Optional |  Set it to true to install packages in local machine. It is not required if script is running from Azure Cloud Shell        |
	|    DISK_NAME   | Optional |  Name for the managed disk that will be created. Default value is mariner         |
	|    STORAGE_TYPE | Optional | Underlying storage SKU. Default value is Premium_LRS  |
	|    VM_NAME  | Optional |  Name of the VM that will be created. Default value is marinervm |
	|    VM_SIZE  | Optional |  The VM size to be created. Default value is Standard_DS2_v2  |

1. Run the [setup-brainbox-vm.sh](/setup-brainbox-vm.sh) script 

1. Note down the public IP of the VM. This will be used later in deployment script as EDGE_DEVICE_IP.

	![Note down IP](/MarkdownImages/obfuscated_note_down_azure_vm_ip.png)

1. 	Add a SSH rule in Network Security Group of the VM to allow your machine to connect to VM. 
	
	Select Networking blade in VM on Azure Portal. Click on Add inbound port rule

	![Inbound SSH rule](/MarkdownImages/add_nsg_rule_step_1.png)	
	Add values in inbound port rule and select add.

	![Inbound SSH rule](/MarkdownImages/add_nsg_rule_step_2.png)

	If your tenant has enabled Azure Core Security Managed Policy, a default rule blocking SSH port may be auto added to the Network Security Group. You can update that rule to allow access to your IP.

1. Test connectivity to the Brainbox VM

	```
	ssh root@<brainbox-ip>
	Enter password when prompted
	```

	You should see a screen similar to the following when connected to the brainbox machine.

	![Test Connectivity](/MarkdownImages/brainbox_vm_screenshot.png)

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