<!-- Update this title with a descriptive name. Use sentence case. -->
# PowerVS Automation for Oracle Database

<!--
Update status and "latest release" badges:
  1. For the status options, see https://terraform-ibm-modules.github.io/documentation/#/badge-status
  2. Update the "latest release" badge to point to the correct module's repo. Replace "terraform-ibm-module-template" in two places.
-->
[![Graduated (Supported)](https://img.shields.io/badge/status-Graduated%20(Supported)-brightgreen?style=plastic)](https://terraform-ibm-modules.github.io/documentation/#/badge-status)
[![latest release](https://img.shields.io/github/v/release/terraform-ibm-modules/terraform-ibm-powervs-oracle?logo=GitHub&sort=semver)](https://github.com/terraform-ibm-modules/terraform-ibm-powervs-oracle/releases/latest)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://renovatebot.com/)
[![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg)](https://github.com/semantic-release/semantic-release)

<!--
Add a description of modules in this repo.
Expand on the repo short description in the .github/settings.yml file.

For information, see "Module names and descriptions" at
https://terraform-ibm-modules.github.io/documentation/#/implementation-guidelines?id=module-names-and-descriptions
-->

This module creates a Oracle Single Instance 19c Database on IBM PowerVS Private AIX VSI.

## Overview
This automated deployable architecture guide demonstrates the components used to deploy Oracle Single Instance 19c Database on IBM PowerVS Private. First it creates the infrastructure and next it creates the database. The Oracle Database can be either created on Automatic Storage Management (ASM) or on Journal File System (JFS2).

## Reference Architecture

<img width="342" alt="image" src="https://github.com/nava-dba/terraform-ibm-oracle-powervs-da/blob/main/images/Oracle_DA_SI.svg" />

Using terraform, RHEL & AIX vms will be created. The RHEL vm will act as Ansible controller which contains the playbooks required to setup Oracle Database on AIX. The RHEL vm is also configured with NFS server for staging the Oracle binaries.

## Planning
### Before you begin deploying

**Step A**: IAM Permissions
- IAM access roles are required to install this deployable architecture and create all the required elements.
  You need the following permissions for this deployable architecture:
1. Create services from IBM Cloud catalog.
2. Create and modify Power® Virtual Server services, virtual server instances, networks, storage volumes, ssh keys of this Power® Virtual Server.
3. Access existing Object Storage services.
4. The Editor role on the Projects service.
5. The Editor and Manager role on the Schematics service.
6. The Viewer role on the resource group for the project.

- For information about configuring permissions, contact your account administrator. For more details refer to [IAM in IBM Cloud](https://cloud.ibm.com/docs/account?topic=account-cloudaccess).

**Step B**: Generate API key on the target account
- Refer to the [IBM Documentation](https://www.ibm.com/docs/en/masv-and-l/cd?topic=cli-creating-your-cloud-api-key)

**Step C**: Create Power Virtual Server Workspace and get guid.
1. To create an IBM Power® Virtual Server workspace, complete step 1 to step 8 from the IBM PowerVS documentation for [Creating an IBM Power® Virtual Server](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-creating-power-virtual-server)
2. Click on Menu --> “Resource List” --> Expand “Compute” --> Click on the blue circle dot on the left side of the workspace and copy the GUID
3. GUID can also be obtained from CRN of the workspace.

For example: This is the CRN:

> crn:v1:bluemix:public:power-iaas:dal14:a12hkf7gtug9f945688c021cd0n5f45c4d:**6284g5a2-4771-4b3b-g20h-278bb2b7651e**::

> The corresponding GUID is **6284g5a2-4771-4b3b-g20h-278bb2b7651e**

**Step D**: Create Private Subnet in PowerVS Workspace
1. Go to the workspace that was created in Step C
2. Click Subnets in the left navigation menu, then Add subnet.
3. Enter a name for the subnet, CIDR value (for example: 192.168.100.14/24), gateway number (for example: 192.168.100.15), and the IP range values for the subnet.
4. Click Create Subnet.
5. After creation of the subnet, click on the created subnet and note down the "Name" & "ID"

For more information, please refer to [IBM PowerVS Documentation](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-configuring-subnet)

**Step E**: Create VM with external connectivity
1. For PowerVS Public: Goto dashboard Infrastructure->Compute->Virtual server instances; click on "Create",Next assign floating IP to VPC, please refer to [IBM PowerVS Documentation](https://cloud.ibm.com/docs/vpc?topic=vpc-about-advanced-virtual-servers)
   a. To enable the routing between VPC and PowerVS, Create a [transit gateway](https://cloud.ibm.com/docs/transit-gateway?topic=transit-gateway-getting-started) and add PowerVS workspace and VPC to it.
   b. Add the [Security Group](https://cloud.ibm.com/docs/vpc?topic=vpc-using-security-groups)(SG) rule for squid server IP and port. Allow only the traffic from powervs subnet
3. For PowerVS Private: Contact IBM Support, IBM SRE will help in creating a VPN gateway for external connectivity. This will act as bastion host.
For more information, please refer to [IBM PowerVS Documentation](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-private-cloud-architecture#network-spec-private-cloud)

**Step F**: Configure Squid Server on the bastion host for proxy service.
Please refer to [IBM PowerVS Documentation](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-full-linux-sub#create-proxy-private)

**Step G**: Get ssh-key pair from bastion host

Note: If you are using pre-existing keys then make sure private and public ssh key pair are placed in bastion host at ~/.ssh/ and skip the following steps in this section.

1. Generate ssh key pair on the bastion host and add the public key into the bastion host’s authorized keys.
> ssh-keygen -t rsa

> cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

> cat ~/.ssh/id_rsa   # Note down the private key, this must be given as a DA input.

2. Similarly, add the public key of the bastion host to the PowerVS Workspace.
For more information, please refer to [IBM PowerVS Documentation](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-creating-ssh-key)

**Step H**: Download Oracle Binaries and upload to COS bucket
1.Download Oracle Binaries from [Oracle Site](https://edelivery.oracle.com/osdc/faces/SoftwareDelivery) and Release Update(RU) system patches 19.X from [Oracle MOS](https://support.oracle.com).
   - RDBMS Base software: V982583-01_193000_db.zip
   - Grid Infrastructure software: V982588-01_193000_grid.zip
   - Download the latest Release Update(RU) system patch 19.X containing both grid and rdbms RU patches for AIX from MOS. Refer to MOS note [2521164.1](https://support.oracle.com/epmos/faces/DocumentDisplay?parent=DOCUMENT&sourceId=2521164.1&id=2521164.1) and also Refer to this [Oracle documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/downloading-and-installing-patch-updates.html).
2. Create Cloud Object Storage (COS) instance
3. Generate COS service credentials
4. Create COS bucket
5. Upload Oracle files to IBM Cloud COS bucket and note down the COS Service Credentials.
Please refer to the following links related to Cloud Object Storage
   - [Getting started with Cloud Object Storage](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-getting-started-cloud-object-storage)
   - [COS Service Credentials](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-service-credentials)
   - [Upload data to COS Bucket](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-upload)

**Step I**: Full Linux Subscription Implementation
- DA need FLS setup which is required for RHEL Subscription. This release of DA we will be using only IBM provided subscription images, refer to [FLS Documentation](https://www.ibm.com/docs/en/power-virtual-server?topic=linux-full-subscription-power-virtual-server-private-cloud)

**Step J**: Whitelist schematic CIDR/IP
- At VPN Gateway level, whitelist the schematic CIDRs/IPs of region where schematic workspace gets created, refer to [Firewall Access – allowed IP addresses](https://cloud.ibm.com/docs/schematics?topic=schematics-allowed-ipaddresses)

## Deploying
### Deploy using projects
1. Go to the catalog and search for oracle. Under catalog community registry, select tile "Power Virtual Server - Private for Oracle".
2. Click "Configure and deploy"
3. Next, we will deploy the DA using the IBM Cloud projects.
Refer to this link for more information about [Projects](https://cloud.ibm.com/docs/secure-enterprise?topic=secure-enterprise-understanding-projects)
4. Select and Review the deployment options
5. Select the Add to project deployment type in Deployment options, and then click Add to project
6. Name your project, enter a description, and specify a configuration name. Click Create.
7. Edit and validate the configuration:
   1.	Enter values for required input fields
   2.	Review and update the optional inputs if needed
   3.	Save the configuration
   4.	Click Validate, validation takes a few minutes
   5.	Click Deploy (Deploying the deployable architecture can take more than 2 hours. You are notified when the deployment is successful)
   6.	Review the outputs from the deployable architecture

After Deployment Oracle Single Instance 19.X Multipurpose non-CDB Database will get created on AIX. You can connect to AIX VM from VPN Gateway VM(VPC) or from gui console by resetting the root password.

```
COMP_ID         COMP_NAME                                          STATUS
--------------- -------------------------------------------------- --------------------------------------------
CATALOG         Oracle Database Catalog Views                      VALID
CATPROC         Oracle Database Packages and Types                 VALID
RAC             Oracle Real Application Clusters                   OPTION OFF
JAVAVM          JServer JAVA Virtual Machine                       VALID
XML             Oracle XDK                                         VALID
CATJAVA         Oracle Database Java Packages                      VALID
APS             OLAP Analytic Workspace                            VALID
XDB             Oracle XML Database                                VALID
OWM             Oracle Workspace Manager                           VALID
CONTEXT         Oracle Text                                        VALID
ORDIM           Oracle Multimedia                                  VALID
SDO             Spatial                                            VALID
XOQ             Oracle OLAP API                                    VALID
OLS             Oracle Label Security                              VALID
DV              Oracle Database Vault                              VALID
```

## Oracle Single Instance Deployable Architecture Inputs


|  Deployment Inputs   | Terraform Input |     Description              | Accepted Values |
|------------------|----------------|-----------------------------------|----------------|
|     API Key      | ibmcloud_api_key |  IBM Cloud API key used to authenticate and provision resources. To generate an API key, see [Creating your IBM Cloud API key](https://www.ibm.com/docs/en/masv-and-l/cd?topic=cli-creating-your-cloud-api-key)|                |
| Deployment Type    | deployment_type| Deployment type for the architecture. | Public or Private |
| Resource Name Prefix| prefix | Unique identifier prepended to all resources created by this template. |Use only lowercase letters with maximum 5 characters and allows only alpha-numeric and hyphen characters. Example:dbsi |
| Deployment Region| region | IBM Cloud region where resources will be deployed. See all available regions at [IBM Cloud locations](https://cloud.ibm.com/docs/overview?topic=overview-locations).| Example: Dallas, Frankfurt |
| PowerVS Zone | zone | IBM Cloud data center zone within the region where IBM PowerVS infrastructure will be created (e.g., dal14, eu-de-1). See all available zones at [IBM PowerVS locations](https://www.ibm.com/docs/en/power-virtual-server?topic=locations-cloud-regions).| Example: dal10 |
| PowerVS Workspace GUID | pi_existing_workspace_guid | GUID of an existing IBM Power Virtual Server Workspace. To find the GUID: IBM Cloud Console > Resource List > Compute > click the workspace > copy the GUID from the CRN (the segment between the 7th and 8th colon). To create a new workspace, see [Creating an IBM Power Virtual Server](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-creating-power-virtual-server).| n/a|
| Bastion Host IP Address | bastion_host_ip | Public IP address of the bastion/jump host used to reach the Ansible controller (RHEL instance) in the private network. The bastion host must have the SSH private key at ~/.ssh/id_rsa. To set up a VPN gateway as the bastion host, contact IBM Support. For more information, see [IBM PowerVS Private Cloud Network Architecture](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-private-cloud-architecture#network-spec-private-cloud).| Floating IP Address|
| Bastion Host SSH Public Key Name | pi_ssh_public_key_name | Name of the existing SSH public key already uploaded to the PowerVS Workspace. To add an SSH key to the workspace, see [Managing IBM PowerVS SSH keys](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-creating-ssh-key). | n/a|
| Bastion Host SSH Private Key | ssh_private_key | RSA private SSH key corresponding to the public key referenced by 'pi_ssh_public_key_name'. Used to connect to IBM PowerVS instances during provisioning. The key is stored temporarily and deleted after use. To generate a key pair on the bastion host, run: ssh-keygen -t rsa, then copy the output of: cat ~/.ssh/id_rsa. For more information, see [SSH keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys).| n/a |
| PowerVS Networks | pi_networks | List of existing private subnet objects to attach to the instance. The first element becomes the primary network interface. Each object requires 'name' and 'id'. To list available subnets, run: ibmcloud pi networks. To create a subnet, see [Configuring a subnet](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-configuring-subnet). | [ { name = "ora_net" id = "c38d18ad-b39f-4ba0-94f0-ada107ab64df" } ] |
| RHEL Management Server Type | pi_rhel_management_server_type | Server (machine) type for the RHEL management (Ansible controller) instance. To list available server types, run: ibmcloud pi server-types. | e.g., s1022, e980 |
| Squid - Proxy Server IP Address | squid_server_ip | Private IP address of the Squid proxy server that provides internet access from within the private PowerVS network. Required for downloading packages and patches during installation. To configure a Squid proxy server, see [Creating a proxy server](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-full-linux-sub#create-proxy-private). | Private IP |
| Oracle Database Name (SID) | ora_sid | Oracle Database System Identifier (SID). A unique name for the Oracle database instance (e.g., ORCL). Maximum 8 characters, alphanumeric, must start with a letter. For more information, see [Oracle Database Concepts](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/introduction-to-oracle-database.html). | n/a |
| Storage Type (ASM or File System JFS2) | oracle_install_type | Oracle storage installation type. Use 'ASM' for Automatic Storage Management (requires Grid Infrastructure binaries in COS and 'cos_oracle_grid_sw_path' set) or 'JFS' for Journal File System (JFS2). ASM is recommended for production environments. | ASM or JFS2
| Cloud Object Storage(COS) Credentials | ibmcloud_cos_service_credentials | JSON service credentials for the IBM Cloud Object Storage instance used to access the COS bucket. To generate credentials: IBM Cloud Console > Cloud Object Storage > your instance > Service Credentials > New credential. See [COS Service Credentials](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-service-credentials) for a JSON example. | | # pragma: allowlist secret
| COS Oracle Software Storage Configuration | ibmcloud_cos_configuration | IBM Cloud Object Storage details to download the files to the target host. | |
| AIX OS Image Name | pi_aix_image_name | Name of the IBM PowerVS AIX boot image used to host the Oracle Database. Must be a valid AIX image available in the workspace. To list available images, run: ibmcloud pi images.| Example: 7300-04-00 |
| AIX Instance Configuration(CPU,Mem) | pi_aix_instance | Configuration for the IBM PowerVS AIX instance where Oracle Database will be installed. Fields: memory_gb (RAM in GB), cores (number of virtual processors), core_type (shared / capped / dedicated), machine_type (e.g., s1022 or e980), pin_policy (hard / soft), health_status (OK / Warning / Critical). | { "core_type": "shared",  "cores": 0.5, "health_status": "OK", "machine_type": "s1022", "memory_gb": "16", "pin_policy": "hard" }|
| Oracle Software Binary Disks | pi_oravg_volume | Disk configuration for the Oracle software volume group (oravg). Fields: name (default: oravg), size (disk size in GB), count (number of disks), tier (storage tier, e.g., tier1 or tier3). | { "count": "2", "size": "100", "tier": "tier1" } |
| Database Data Disks | pi_data_volume | Disk configuration for the DATA volume. Used as the DATA diskgroup in ASM mode or as DATAVG in JFS2 mode. Fields: name (default: DATA), size (disk size in GB), count (number of disks), tier (storage tier, e.g., tier1 or tier3). | {  "count": "8",  "size": "5",  "tier": "tier1" } |
| Redo Log Disks | pi_redo_volume | Disk configuration for the REDO volume. Used as the REDO diskgroup in ASM mode or as REDOVG in JFS2 mode. Fields: name (default: REDO), size (disk size in GB), count (number of disks), tier (storage tier, e.g., tier1 or tier3). | { "count": "4",  "size": "2",  "tier": "tier5k" } |
| Redo log member size (MB) | redolog_size_in_mb | Size of each redo log member in megabytes (MB). Recommended minimum is 500 MB for production workloads. | Example: 1024 |
| Resource Tags | pi_user_tags | List of tag names to apply to all IBM Cloud PowerVS instances and volumes created by this module. Can be set to null to skip tagging. | Example: ["oracledb"] |

## Help and Support
You can report issues and request features for this module in GitHub issues in the [repository link](https://github.com/terraform-ibm-modules/.github/blob/main/.github/SUPPORT.md)
