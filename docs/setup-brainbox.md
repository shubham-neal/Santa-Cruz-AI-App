
## Brainbox VM Creation

Follow these steps to create brainbox VM.

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

	1. Run the [setup-brainbox-managed-disk.sh](/../setup-brainbox-managed-disk.sh) script 

1. Create a new VM from disk

	Using Azure portal:
	1. Open the managed disk created in above step in Azure Portal
	1. Select "Create VM"

		![Create VM using Managed Disk](/MarkdownImages/create_vm_azure_portal_step_1.png)
		
	1. Provide name to the VM, select None in Public Inbound Ports and click on Create+Review

		![Create VM](/MarkdownImages/create_vm_azure_portal_step_2.png)

	1. Click on Create
	
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
	1. Run the [setup-brainbox-vm.sh](/../setup-brainbox-vm.sh) script 

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