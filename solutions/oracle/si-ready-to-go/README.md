<!-- Update this title with a descriptive name. Use sentence case. -->
# PowerVS Automation for Oracle Single Instance Database - One Click

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

This module offers fully automated solution for deploying Oracle Single Instance 19c Database on IBM PowerVS AIX Virtual Server Instance(VSI).
## Overview

This fully automated deployable architecture creates a complete Oracle Database 19c Single Instance environment on IBM Power Virtual Server (PowerVS) with integrated PowerVS VPC landing zone infrastructure. It eliminates the need for pre-existing PowerVS workspaces and manual configuration scripts.

## Reference Architecture

<img width="450" alt="image" src="https://github.com/nava-dba/terraform-ibm-oracle-powervs-da/blob/main/images/Oracle_DA_SI_FA.svg" />

This solution deploys:

#### VPC Landing Zone Infrastructure
- **Management VSI (Bastion Host)**: Secure SSH access point with floating IP
- **Network Services VSI**: Hosts SQUID proxy, DNS forwarder, NTP server, NFS server, and Ansible execution node
- **Transit Gateway**: Connects VPC to PowerVS workspace
- **VPC Networking**: Subnets, security groups, and network ACLs
- **Optional Components**: Client-to-site VPN, IBM Cloud Monitoring, Security and Compliance Center Workload Protection

For more details refer to IBM Cloud docs [Power Virtual Server with VPC landing zone](https://cloud.ibm.com/docs/powervs-vpc?topic=powervs-vpc-automation-solution-overview)

#### PowerVS Infrastructure
- **PowerVS Workspace**: Automatically created in specified zone
- **Management Network**: Private network for Oracle instance communication
- **AIX VSI**: Hosts Oracle Database 19c with configurable resources
- **Storage**: Automatic configuration for Oracle ASM or JFS2 filesystems

#### Automated Configuration
- Network services (proxy, DNS, NTP, NFS) configured via Ansible
- Oracle binaries downloaded from IBM Cloud Object Storage
- Oracle Grid Infrastructure installation (if using ASM)
- Oracle Database 19c installation and configuration
- Database creation with specified SID

## Key Features

✅ **Fully Automated**: No manual steps required after deployment
✅ **Production Ready**: Based on IBM's standard-plus-vsi reference architecture
✅ **No Pre-requisites**: Creates all infrastructure from scratch
✅ **Flexible Storage**: Supports both Oracle ASM and JFS2 filesystems
✅ **Secure**: Built-in VPN support, security groups, and compliance options
✅ **Scalable**: Configurable compute and storage resources

## Prerequisites

### Required
1. **IBM Cloud Account** with appropriate permissions
2. **IBM Cloud API Key** with Editor role or higher. Refer to the [API Keys](https://www.ibm.com/docs/en/masv-and-l/cd?topic=cli-creating-your-cloud-api-key) for detailed description.
3. **SSH Key Pair** (RSA format)
4. **Oracle Binaries** uploaded to IBM Cloud Object Storage:
   - Oracle Database 19c installation files
   - Oracle Grid Infrastructure 19c (if using ASM)
   - Latest Release Update (RU) patch
   - Latest OPatch utility
5. **IBM Cloud Object Storage Service Credentials** (JSON format). Please refer to [COS Service Credentials](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-service-credentials)

### Permissions Required
- PowerVS workspace creation
- VPC infrastructure creation
- Transit Gateway creation
- Resource group access
- Object Storage access

For information about configuring permissions, contact your account administrator. For more details refer to [IAM in IBM Cloud](https://cloud.ibm.com/docs/account?topic=account-cloudaccess).

## Quick Start

### 1. Prepare Oracle Binaries

a) Create the COS bucket and upload oracle binaries.
   Please refer to [Getting started with Cloud Object Storage](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-getting-started-cloud-object-storage)

b) Download Oracle Binaries from [Oracle Site](https://edelivery.oracle.com/osdc/faces/SoftwareDelivery) and Release Update(RU) system patches 19.X from [Oracle MOS](https://support.oracle.com).
   - RDBMS Base software: V982583-01_193000_db.zip
   - Grid Infrastructure software: V982588-01_193000_grid.zip
   - Download the latest System Patch (Release Update) 19.X containing both grid and rdbms RU patches for AIX from My Oracle Support. Refer to this MOS note [2521164.1](https://support.oracle.com/epmos/faces/DocumentDisplay?parent=DOCUMENT&sourceId=2521164.1&id=2521164.1) and also refer to this [Oracle documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/downloading-and-installing-patch-updates.html) to understand more on Oracle patch updates.

c) Upload the Oracle binaries to IBM Cloud COS bucket. Please refer to this documentation to upload the files.
[Upload data to COS Bucket](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-upload)

Example json input of "COS Oracle Software Storage Configuration" deployment input for **JFS2** deployment

```
{
  "cos_bucket_name": "oracle-sw-123",
  "cos_oracle_database_sw_path": "V982583-01_193000_db.zip",
  "cos_oracle_grid_sw_path": "",
  "cos_oracle_opatch_file_path": "p6880880_190000_AIX64-5L.zip",
  "cos_oracle_ru_file_path": "p37641958_190000_AIX64-5L.zip",
  "cos_region": "us-south"
}
```
Example json input of "COS Oracle Software Storage Configuration" deployment input for **ASM** deployment
```
{
  "cos_bucket_name": "oracle-sw-123",
  "cos_oracle_database_sw_path": "V982583-01_193000_db.zip",
  "cos_oracle_grid_sw_path": "V982588-01_193000_grid.zip",
  "cos_oracle_opatch_file_path": "p6880880_190000_AIX64-5L.zip",
  "cos_oracle_ru_file_path": "p37641958_190000_AIX64-5L.zip",
  "cos_region": "us-south"
}
```

### 2. Create COS Service Credentials
In the Cloud Object Instance, click on "Service Credentials" and click on "New Credential". Provide the "Name", set writer to the "Role" and click "Add".

Generate COS service credentials. Please refer to [COS Service Credentials](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-service-credentials)

Save the output JSON for the `ibmcloud_cos_service_credentials` variable.

### 3. Deploy via IBM Cloud Catalog

a. Go to IBM Cloud dashboard and create a new project. Refer to this link for more information about [Projects](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project)

b. Go to the catalog and search for oracle. Under community registry, select tile "Oracle on IBM Power Virtual Server".

c. In "Deployable architecture setup", select the project which was created in step 1.

d. Select the Architecture variation as "Oracle Database SI-One Click"

e. Click "Configure and deploy"

f. Edit and validate the configuration:
   1.	Enter values for required input fields
   2.	Review and update the optional inputs if needed
   3.	Save the configuration
   4.	Click Validate, validation takes a few minutes
   5.	Click Deploy (Deploying the deployable architecture can take more than 2 hours. You are notified when the deployment is successful)
   6.	Review the outputs from the deployable architecture

After Deployment Oracle Single Instance 19.X Multipurpose non-CDB Database will get created on AIX and JFS2 file system is created for archivelogs. You can connect to AIX VM from VPN Gateway VM(VPC) or from gui console by resetting the root password.

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

| Deployment Inputs | Terraform Input Variable | Description | Values |
|---|---|---|---|
| API Key | ibmcloud_api_key | IBM Cloud API key used to authenticate and provision resources. To generate an API key, see [Creating your IBM Cloud API key](https://www.ibm.com/docs/en/masv-and-l/cd?topic=cli-creating-your-cloud-api-key). | |
| Deployment Type | deployment_type | This solution supports both [PowerVS Public](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-getting-started) & [PowerVS Private](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-private-cloud-architecture), which can be controlled by this input variable. | Public or Private |
| Resource Name Prefix | prefix | Unique identifier prepended to all resources created by this template. | Use only lowercase letters with maximum 5 characters and allows only alpha-numeric and hyphen characters. Example: dbsi |
| Deployment Region | region | IBM Cloud region where resources will be deployed. See all available regions at [IBM Cloud locations](https://cloud.ibm.com/docs/overview?topic=overview-locations). | Example: Dallas |
| PowerVS Zone | zone | IBM Cloud data center zone within the region where IBM PowerVS infrastructure will be created (e.g., dal14, eu-de-1). See all available zones at [IBM PowerVS locations](https://www.ibm.com/docs/en/power-virtual-server?topic=locations-cloud-regions). For PowerVS Private, provide [Satellite Zone](https://www.ibm.com/docs/en/power-virtual-server?topic=locations-satellite-location) details. | Public: dal14 &nbsp; Private: satloc_dal_XXXX |
| External Access IP (CIDR) | external_access_ip | This is the IP address of the machine from where you want to ssh into the deployed resources. It could be the IP of the workstation or CIDR of the IP address. | Example IP address format: 203.1.113.5/32, Example CIDR format: 203.1.0.0/16. Using 0.0.0.0/0 is insecure and allows login from any machine |
| SSH Public Key | ssh_public_key | RSA public key for VSI access. The key is stored temporarily and deleted after use. Note: For same region deployments the ssh key should be unique.  | n/a |
| SSH Private Key | ssh_private_key | RSA private key corresponding to the public key, used for internal Ansible automation. The key is stored temporarily and deleted after use. Save the key, helps in logging to AIX VSI. Note: For same region deployments the ssh key should be unique.  | n/a |
| Storage Type (ASM or File System JFS2) | oracle_install_type | Oracle storage installation type. Use `ASM` for Automatic Storage Management (requires Grid Infrastructure binaries in COS and `cos_oracle_grid_sw_path` set) or `JFS2` for Journal File System. | ASM or JFS2 |
| Oracle Database Name (SID) | ora_sid | Name for the Oracle database, must be atleast 3 characters and not more than 8 characters. | Example: orcldb |
| Oracle SYS Password | ora_db_password | Password for Oracle database administrative users (SYS, SYSTEM). Password must be 8-30 characters long and contain at least one uppercase letter, one lowercase letter, one digit, and one special character. | n/a |
| Cloud Object Storage (COS) Credentials | ibmcloud_cos_service_credentials | JSON service credentials for the IBM Cloud Object Storage instance used to access the COS bucket. To generate credentials: IBM Cloud Console > Cloud Object Storage > your instance > Service Credentials > New credential. See [COS Service Credentials](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-service-credentials). | | <!-- pragma: allowlist secret -->
| COS Oracle Software Storage Configuration | ibmcloud_cos_configuration | IBM Cloud Object Storage (COS) bucket details containing Oracle installation binaries. Do not add a leading `/` to any path. | |
| powervs_resource_group_name (Optional) | powervs_resource_group_name | Existing IBM Cloud resource group name. | Example: oracle-da |
| Resource Tags (Optional) | pi_user_tags | List of tag names to apply to all IBM Cloud PowerVS instances and volumes created by this module. Can be set to null to skip tagging. | Example: ["oracledb"] |
| Oracle Network CIDR | powervs_oracle_network_cidr | Network range for dedicated Oracle network. Used for Oracle Database communication. | Example: 10.51.0.0/24 |
| AIX OS Image Name (Optional) | pi_aix_image_name | Name of the IBM PowerVS AIX boot image used to host the Oracle Database. Must be a valid AIX image available in the workspace. To list available images, run: `ibmcloud pi images`. | Example: 7300-04-00 |
| AIX Instance Configuration (CPU, Mem) (Optional) | pi_aix_instance | Configuration for the IBM PowerVS AIX instance where Oracle Database will be installed. Fields: `memory_gb`, `cores`, `core_type` (shared / capped / dedicated), `machine_type` (e.g., s1022 or e980), `pin_policy` (hard / soft), `health_status`. | |
| Oracle Software Binary Disks (Optional) | pi_oravg_volume | Disk configuration for the Oracle software volume group (oravg). Fields: `name` (default: oravg), `size` (GB), `count` (number of disks), `tier` (e.g., tier1 or tier3). | |
| Database Data Disks (Optional) | pi_data_volume | Disk configuration for the DATA diskgroup (ASM) or DATAVG (JFS2). Fields: `name`, `size` (GB), `count`, `tier`. | |
| Redo Log Disks (Optional) | pi_redo_volume | Disk configuration for the REDO diskgroup (ASM) or REDOVG (JFS2). Fields: `name`, `size` (GB), `count`, `tier`. | |
| Redo Log Member Size in MB (Optional) | redolog_size_in_mb | Size of each redo log member in megabytes. Recommended minimum is 500 MB for production workloads. | Example: 1024 |
| NFS Server Configuration (Optional) | nfs_server_config | Configuration for the NFS server. 'size' is in GB, 'iops' is maximum input/output operation performance bandwidth per second, 'mount_path' defines the target mount point on os. Set 'configure_nfs_server' to false to ignore creating file storage share. | n/a |
| Client-to-Site VPN Configuration (Optional) | client_to_site_vpn | VPN configuration - the client ip pool to access the environment. If enabled, then a Secret Manager instance is also provisioned with certificates generated. | Example: client_ip_pool: "162.140.0.0/16", enable: true or false |
| VPC Subnet CIDRs (Optional) | vpc_subnet_cidrs | CIDR values for the VPC subnets to be created. Must be new IP pools to avoid collision with existing networks. It is customer responsibility that none of the defined networks collide, including the PowerVS subnets and VPN client pool. Refer to [Power Virtual Server Landing Zone](https://cloud.ibm.com/docs/powervs-vpc?topic=powervs-vpc-landing-zone-preset). | |
| VPC Intel VSI OS Images (Optional) | vpc_intel_images | Stock OS image names for creating VPC landing zone VSI instances: RHEL (management and network services) and SLES (monitoring). Refer to [Stock Images](https://cloud.ibm.com/infrastructure/compute/stockImages) for the list of available images. | Example: rhel_image: ibm-redhat-9-4-amd64-sap-applications-5 |
| Secrets Manager Service Plan (Optional) | sm_service_plan | This needs to be configured when Client-to-Site VPN is required. Service plan for a new Secrets Manager instance. Only used when existing_sm_instance_guid is not set | Standard or Trial |
| Existing Secrets Manager GUID (Optional) | existing_sm_instance_guid | This needs to be configured when Client-to-Site VPN is required. GUID of an existing Secrets Manager instance. Leave blank to provision a new one. | |
| Existing Secrets Manager Region (Optional) | existing_sm_instance_region | This needs to be configured when Client-to-Site VPN is required. Region of the existing Secrets Manager instance. Required only when existing_sm_instance_guid is provided. | |

## Post-Deployment

### Access the Environment

1. **SSH to Baston/Management host via Floating IP and then connect to Network services Host**:
   ```bash
   ssh -i <rsa-prvt-key> root@<access_host_or_ip>
   ```
  If you are using client-to-site vpn, you can directly login to Management Host

2. **SSH to Oracle AIX Instance**:
   ```bash
   ssh -i <rsa-prvt-key> root@<oracle_aix_instance_management_ip>
   ```

3. **Connect to Oracle Database**:
   ```bash
   su - oracle
   sqlplus / as sysdba
   ```

### Verify Installation

```sql
-- Check database status
SELECT instance_name, status FROM v$instance;

-- Check ASM diskgroups (if using ASM)
SELECT name, state, total_mb, free_mb FROM v$asm_diskgroup;

-- Check tablespaces
SELECT tablespace_name, status FROM dba_tablespaces;
```

## Troubleshooting

### Common Issues

1. **Deployment Fails During Oracle Installation**
   - Check COS credentials are valid
   - Verify Oracle binaries are uploaded correctly
   - Check AIX instance has sufficient resources

2. **Cannot Access Management Host**
   - Verify `external_access_ip` includes your IP
   - Check security group rules
   - Ensure floating IP is assigned

3. **Network Services Not Working**
   - Check Transit Gateway connections
   - Verify PowerVS network configuration
   - Review Ansible execution logs

### Logs Location

- **Ansible Logs**: `/tmp/ansible-*.log` on Network Services VSI
- **Oracle Installation Logs**: `/tmp/oracle_install.log` on AIX instance
- **Terraform Logs**: Set `TF_LOG=DEBUG` for detailed output

## Support

- **GitHub Issues**: [terraform-ibm-oracle-powervs-da/issues](https://github.com/terraform-ibm-modules/terraform-ibm-oracle-powervs-da/issues)
- **IBM Cloud Docs**: [Power Virtual Server Documentation](https://cloud.ibm.com/docs/power-iaas)
- **Community**: IBM Cloud Community Forums

## License

This solution is licensed under the Apache License 2.0. See LICENSE file for details.

## Contributing

Contributions are welcome! Please read CONTRIBUTING.md for guidelines.
