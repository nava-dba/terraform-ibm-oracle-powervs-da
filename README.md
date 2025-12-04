<!-- Update this title with a descriptive name. Use sentence case. -->
# PowerVS Private Automation for Oracle Database

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

<img width="342" alt="image" src="https://raw.githubusercontent.com/nava-dba/terraform-ibm-powervs-oracle/a96f103b364a8c7b1c2682da4c4067631f070d6c/images/Oracle_Private_DA_SI.svg" />

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

- For information about configuring permissions, contact your account administrator.

**Step B**: Generate API key
- Refer to the [IBM Documentation](https://www.ibm.com/docs/en/masv-and-l/cd?topic=cli-creating-your-cloud-api-key)

**Step C**: Create Power Virtual Server Workspace and get guid.
1. To create an IBM Power® Virtual Server workspace, complete step 1 to step 8 from the IBM PowerVS documentation for [Creating an IBM Power® Virtual Server](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-creating-power-virtual-server)
2. Click on Menu --> “Resource List” --> Expand “Compute” --> Click on the blue circle dot on the left side of the workspace and copy the GUID
3. GUID can also be obtained from CRN of the workspace.

For example: This is the CRN:

> crn:v1:bluemix:public:power-iaas:dal14:a12hkf7gtug9f945688c021cd0n5f45c4d:**6284g5a2-4771-4b3b-g20h-278bb2b7651e**::

> The corresponding GUID is **6284g5a2-4771-4b3b-g20h-278bb2b7651e**

**Step D**: Create Private Subnet in PowerVS Workspace
1. Go to the workspace that was created in Step 3
2. Click Subnets in the left navigation menu, then Add subnet.
3. Enter a name for the subnet, CIDR value (for example: 192.168.100.14/24), gateway number (for example: 192.168.100.15), and the IP range values for the subnet.
4. Click Create Subnet.

For more information, please refer to [IBM PowerVS Documentation](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-configuring-subnet)

**Step E**: Create VM with external connectivity
- Contact IBM Support, IBM SRE will help in creating a VPN gateway for external connectivity. This will act as bastion host.
For more information, please refer to [IBM PowerVS Documentation](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-private-cloud-architecture#network-spec-private-cloud)

**Step F**: Configure Squid Server on the bastion host for proxy service.
Please refer to [IBM PowerVS Documentation](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-full-linux-sub#create-proxy-private)

**Step G**: Get ssh-key pair from bastion host
1. Generate ssh key pair on the bastion host and add the public key into the bastion host’s authorized keys.
> ssh-keygen -t rsa

> cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

> cat ~/.ssh/id_rsa   # Note down the private key, this must be given as a DA input.
  Note: If you are using pre-existing keys then make sure private and public ssh key pair are placed in bastion host at ~/.ssh/
2. Similarly, add the public key of the bastion host to the PowerVS Workspace.
For more information, please refer to [IBM PowerVS Documentation](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-creating-ssh-key)

**Step H**: Download Oracle Binaries and upload to COS bucket
1. Create COS instance
2. Generate COS service credentials
3. Create COS bucket
4. Download Oracle Binaries from [Oracle Site](https://www.oracle.com/database/technologies/oracle19c-aix-193000-downloads.html). They should be uploaded to IBM Cloud COS bucket and note down the COS Service Credentials. The following files must be downloaded.
   - RDBMS software: AIX.PPC64_193000_db_home.zip
   - Grid Infrastructure software: AIX.PPC64_193000_grid_home.zip
   - Download the latest Release Update patch for AIX from MOS. Refer to this [Oracle documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/downloading-and-installing-patch-updates.html) to get the patches.
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
1. Go to the catalog community registry and search for powervs_oracle_da
2. Next, we will deploy the DA using the IBM Cloud projects.
Refer to this link for more information about [Projects](https://cloud.ibm.com/docs/secure-enterprise?topic=secure-enterprise-understanding-projects)
3. Click on the tile for the deployable architecture
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

## Help and Support
You can report issues and request features for this module in GitHub issues in the [repository link](https://github.com/terraform-ibm-modules/.github/blob/main/.github/SUPPORT.md)
