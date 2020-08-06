
## Mariner VM Creation

Follow these steps to create Mariner VM.

1. Configure following variables in [variables.template](/variables.template)


	|    Variable Name  | Is it Required? | Description |
	|---------------------|-------------|-------------|
	|    USE_INTERACTIVE_LOGIN   | Optional |  Set it to true to use interactive login. If it's not set to true, service principal will be used for login. This is not required for Azure Cloud Shell environment. Script will use existing login of Azure Cloud Shell.   |
	|    TENANT_ID  | Optional |  ID for your tenant. This is not required for Azure Cloud Shell environment. Script will use existing login of Azure Cloud Shell. |
	|    SP_APP_ID   | Optional |   Client ID of Service Principal for login. Only required if USE_INTERACTIVE_LOGIN is not set to true and current environment is not Azure Cloud Shell. Script will use existing login of Azure Cloud Shell.         |
	|    SP_APP_PWD   | Optional |  Client Secret of Service Principal for login. Only required if USE_INTERACTIVE_Login is not set to true and current environment is not Azure Cloud Shell. Script will use existing login of Azure Cloud Shell.          |
	|    SUBSCRIPTION_ID     | Required | ID for your subscription         |
	|    RESOURCE_GROUP | Required | Resource Group Name or ID          |
	|    LOCATION   | Required |  Azure Region location         |
    |    USE_EXISTING_RESOURCES| Required |If the value is set to "yes", the script will use an existing resources if they are already present in Azure. If it is not set to true, the script will fail for Resource Group if there is already an existing resource group with the given name in Azure. For other resources, it will create new resources by appending a random number to the given names|
	|    INSTALL_REQUIRED_PACKAGES   | Optional |  Set it to true to install packages in local machine. It is not required if script is running from Azure Cloud Shell        |
	|    DISK_NAME   | Optional |  Name for the managed disk that will be created. Default value is mariner         |
	|    STORAGE_TYPE | Optional | Underlying storage SKU. Default value is Premium_LRS  |
	|    VM_NAME  | Optional |  Name of the VM that will be created. Default value is marinervm |
	|    VM_SIZE  | Optional |  The VM size to be created. Default value is Standard_DS2_v2  |

1. Run the [mariner-vm-setup.sh](/mariner-vm-setup.sh) script 

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

- Convert disk from vhdx to vhd using Hyper-V conversion tool
- Expand disk from 10GB to 64GB using Hyper-V conversion tool
- Upload VHD file to blob storage