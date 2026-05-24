<!-- Update this title with a descriptive name. Use sentence case. -->
# PowerVS Automation for Oracle Real Application Clusters

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

This module creates a Oracle Real Application Clusters(RAC) 19c Database on IBM PowerVS AIX Virtual Server Instances (VSIs).


## Overview

This automated deployable architecture guide demonstrates how to deploy an Oracle 19c RAC Database on IBM PowerVS Public or Private AIX VSIs. The deployment process is divided into two main stages. In the first stage, the required infrastructure is provisioned. In the second stage, the Oracle database is created and configured on RAC. This solution currently supports only **2 node** RAC deployment.

## Reference Architecture

<img width="342" alt="image" src="https://raw.githubusercontenhttps://raw.githubusercontent.com/terraform-ibm-modules/terraform-ibm-powervs-oracle/0859fa3a4c1581e6db02c0cc7f8e9cf104976e05/images/Oracle_DA_RAC.svg" />

Using Terraform, both RHEL and AIX virtual machines are provisioned as part of the deployment. The RHEL VM acts as the Ansible controller, hosting the playbooks required to install and configure the Oracle Database on the AIX system. It is also configured with an NFS server to stage and provide access to the Oracle installation binaries for the AIX VMs and DNS server for the name resolution of RAC VIPs.

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
1. Login in your IBM Cloud account.
2. In the Manage menu, select Access (IAM).
3. In the API keys menu, click Create button.
4. In the Create IBM Cloud API key page, enter a name and description for your API Key.
5. In the Leaked key section, select either to disable, delete, or not take any action if a key is discovered.
6. In the Select creation section, choose whether the API key should create a session in the CLI or not.
   - Refer to the [API Keys](https://www.ibm.com/docs/en/masv-and-l/cd?topic=cli-creating-your-cloud-api-key) for detailed description.

**Step C**: Create Power Virtual Server Workspace and get guid & PowerVS zone
1. To create an IBM Power® Virtual Server workspace follow the steps from 1 to 8 of [Creating an IBM Power® Virtual Server](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-creating-power-virtual-server)
2. Once the Workspace is created get the GUID, Go to IBM Cloud dashboard -> "Resource List" -> "Compute" --> Click on the blue circle dot on the left side of the workspace and copy the GUID.
4. GUID can also be obtained from CRN of the workspace.

For example: This is the CRN:

> crn:v1:bluemix:public:power-iaas:**dal14**:a12hkf7gtug9f945688c021cd0n5f45c4d:**6284g5a2-4771-4b3b-g20h-278bb2b7651e**::

> The corresponding GUID is **6284g5a2-4771-4b3b-g20h-278bb2b7651e**

> The corresponding zone is **dal14**

**Step D**: Create the subnets for Oracle RAC in PowerVS Workspace. Below are the steps to create a single subnet.
1. Go to the workspace that was created in Step C.
2. Click on "Subnets" in the left navigation menu, then click on "Create subnet".
3. Enter the following
   - "Name" for the subnet
   - CIDR value (Example: 10.40.80.0/24)
   - Gateway number (Example: 10.40.80.1), the IP range values for the subnet (Example: 10.40.80.2 — 10.40.80.254)
   - DNS server (Example: 161.26.0.10).
   - Click "Create subnet"
4. Click on the created subnet to get the "Name" & "ID" details.

For more information, please refer to [Configuring Subnets](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-configuring-subnet)

**Note:** For Oracle RAC interconnect subnet provide the MTU value as 9000

For RAC deployment, we need 4 subnets.
1. Management network
2. Oracle RAC Public
3. Oracle RAC Private1
4. Oracle RAC Private2

**PowerVS Public:** During Creation of Oracle RAC Subnets(Public and Private), Enable ARP option. Supports both "Same Server" and "Different Server" placement policies.

**PowerVS Private:** Doesn't have ARP option. In Private use "Same Server" placement policy for deployment. If you want "Different Server" placement policy Contact IBM support to enable the ARP for the subnet.

**Note:** For ora-rac-pub subnet IP Range should be mentioned from 0-240. Rest of them are reserved for Public networks. The IPs 172.16.10.241 to 172.16.10.254 are reserved for Oracle RAC VIPs(SCAN and Node-VIPs)

| Name | Subnet Name | CIDR | IP Range | ARP Broadcast | MTU |
|------|------|------|----------|-----|-----|
| Management network | ora_net | 10.40.80.0/24 | 10.40.80.2 — 10.40.80.254 | Disabled | 1450 |
| Oracle RAC Public | ora-rac-pub | 172.16.10.0/24 | 172.16.10.2 — 172.16.10.240 | Enabled | 1450 |
| Oracle RAC Private1 | ora-rac-priv1 | 10.60.30.0/28 | 10.60.30.2 — 10.60.30.14 | Enabled | 9000 |
| Oracle RAC Private2 | ora-rac-priv2 | 10.50.20.0/28 | 10.50.20.2 — 10.50.20.14 | Enabled | 9000 |


Below is the screenshot from IBM Cloud GUI
<img width="800" alt="image" src="https://raw.githubusercontent.com/terraform-ibm-modules/terraform-ibm-powervs-oracle/refs/heads/main/images/ora_rac_subnets.png" />

Deployment input for "PowerVS Networks" should be mentioned in this order only.

Example:

```
[
  {
    name = "ora_net"
    id   = "c38d18ad-b39f-4ba0-94f0-ada107ab64df"
  },
  {
    name = "ora-rac-pub"
    id   = "47e38742-5850-411a-95ba-80fea41c12ec"
  },
  {
    name = "ora-rac-priv1"
    id   = "65167db2-715a-4cb9-b600-806c77d33cc4"
  },
  {
    name = "ora-rac-priv2"
    id   = "856db87c-cb23-416d-898b-834bb2b8e0bc"
  }
]
```

**Step E**: Create a Bastion Host (VPC) on IBM Cloud with external connectivity
<br>Bastion host is an x86 based vm in IBM Cloud called as [VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-about-advanced-virtual-servers). This acts like a jump server to connect to the resources in the PowerVS workspace.
1. Public: Go to IBM Cloud Dashboard and click on "Infrastructure" -> "Compute" -> "Virtual server instances"; click on "Create".
   - Next, add a floating IP to the bastion host, this [Floating IP](https://cloud.ibm.com/docs/vpc?topic=vpc-fip-about) allows users to access the bastion host from the public network.
   - To enable the routing between VPC and PowerVS Workspace created in Step C, Create a ["Transit Gateway"](https://cloud.ibm.com/docs/transit-gateway?topic=transit-gateway-getting-started) and add PowerVS workspace and VPC to it.

2. Private: Contact IBM Support, IBM SRE will help in creating a VPN gateway for external connectivity. This will act as bastion host.
For more information related to Private Cloud Architecture, please refer to [IBM PowerVS Private](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-private-cloud-architecture#network-spec-private-cloud)

Sample Bastion Host details:

<img width="800" alt="image" src="https://github.com/terraform-ibm-modules/terraform-ibm-powervs-oracle/blob/main/images/screenshot1.png?raw=true" />

**Step F**: Configure Squid Proxy service on Bastion host

Squid Server is a proxy service which should be configured in the Bastion host, this will allow internet access to the resources in PowerVS workspace.

1. Install squid
   ```bash
   yum update -y
   yum install epel-release
   yum install squid
   ```

2. Update the squid config file `/etc/squid/squid.conf`

   Add and allow http access for the subnet CIDR created in Step D to `/etc/squid/squid.conf` file. Below is the sample squid configuration file.

<details>
<summary><b>📋 Click to view example squid configuration file</b></summary>

Below is a complete `/etc/squid/squid.conf` configuration file example. Adjust the network ranges according to your environment:

```conf
#
# Recommended minimum configuration:
#

# Example rule allowing access from your local networks.
# Adapt to list your (internal) IP networks from where browsing
# should be allowed
acl localnet src 10.40.80.0/24		# ora-net (PowerVS subnet)
acl ibmprivate dst 161.26.0.0/16	# IBM Cloud private network
acl ibmprivate dst 166.8.0.0/14		# IBM Cloud private network
acl SSL_ports port 443 8443
acl Safe_ports port 80			# http
acl Safe_ports port 443			# https
acl Safe_ports port 8443		# 8443

#
# Recommended minimum Access Permission configuration:
#
# Deny requests to certain unsafe ports
http_access deny !Safe_ports

# Deny CONNECT to other than secure SSL ports
http_access deny CONNECT !SSL_ports

# Only allow cachemgr access from localhost
http_access allow localhost manager
http_access deny manager

# This default configuration only allows localhost requests because a more
# permissive Squid installation could introduce new attack vectors into the
# network by proxying external TCP connections to unprotected services.
http_access allow localhost
http_access allow ibmprivate

# The two deny rules below are unnecessary in this default configuration
# because they are followed by a "deny all" rule. However, they may become
# critically important when you start allowing external requests below them.

# Protect web applications running on the same server as Squid. They often
# assume that only local users can access them at "localhost" ports.
http_access deny to_localhost

# Protect cloud servers that provide local users with sensitive info about
# their server via certain well-known link-local (a.k.a. APIPA) addresses.
http_access deny to_linklocal

#
# INSERT YOUR OWN RULE(S) HERE TO ALLOW ACCESS FROM YOUR CLIENTS
#

# For example, to allow access from your local networks, you may uncomment the
# following rule (and/or add rules that match your definition of "local"):
http_access allow localnet

# And finally deny all other access to this proxy
http_access deny all

# Squid normally listens to port 3128
http_port 3128

# Uncomment and adjust the following to add a disk cache directory.
#cache_dir ufs /var/spool/squid 100 16 256

# Leave coredumps in the first cache dir
coredump_dir /var/spool/squid

#
# Add any of your own refresh_pattern entries above these.
#
refresh_pattern ^ftp:		1440	20%	10080
refresh_pattern -i (/cgi-bin/|\?) 0	0%	0
refresh_pattern .		0	20%	4320
```
</details>

3. Save the squid config file and restart the squid service
   ```bash
   # Test configuration syntax
   sudo squid -k parse

   # Restart Squid service
   sudo systemctl restart squid

   # Enable Squid to start on boot
   sudo systemctl enable squid

   # Check Squid status
   sudo systemctl status squid
   ```
For more information on squid, refer to the section ["Configuring the proxy instance"](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-set-full-Linux)

Get the private IP address of Bastion host(VPC) using "ip a" command(Eg. 10.240.64.X). This IP will be given as "Squid - Proxy Server IP Address" input for DA.

**Step G**: Configure NTP on Bastion host

NTP Server is configured on bastion host(VPC), to synchronize the time on PowerVS RHEL VM

1. Check chrony status, by default chrony get installed
   ```bash
   systemctl status chronyd
   ```
2. Update chrony config file /etc/chrony.conf, add the powervs workspace subnet CIDR created in Step D. If port is "port 0", comment it "#port 0" so that it will use the default port 123.
   ```bash
   # Allow NTP client access from local network.
   allow 10.40.80.0/24

3. Restart chrony
   ```bash
   systemctl stop chronyd
   systemctl start chronyd
   systemctl status chronyd
   ```

**Step H**: Add security group rules for squid and ntp on Bastion host

Add a security group rule for squid server IP and port to allow only the traffic from powervs subnet. Similarly add the another security group rule for ntp default port 123. For more information related to Security groups refer to [Security Group](https://cloud.ibm.com/docs/vpc?topic=vpc-using-security-groups)

Sample Security Group Details:

<img width="800" alt="image" src="https://raw.githubusercontent.com/terraform-ibm-modules/terraform-ibm-powervs-oracle/refs/heads/main/images/SG_1.png" />

Note: For more security we can restrict the source in inbound rule to a specific networks instead of 0.0.0.0

**Step I**: Get ssh-key pair from Bastion host

Note: If you are using pre-existing keys then make sure private and public ssh key pair are placed in bastion host at ~/.ssh/ and add public key to authorized_keys, and skip the following steps in this section. Below are the steps for generating the ssh keys

1. Generate ssh key pair on the bastion host and add the public key into the bastion host’s authorized keys.
```
> ssh-keygen -t rsa

> cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

> cat ~/.ssh/id_rsa   # Note down this private key, this must be given as a DA input "Bastion Host SSH Private Key"
```

2. Additionally, add the public key of the bastion host to the PowerVS Workspace.
<br> Go to IBM Cloud Dashboard -> "Compute" -> Click on the <powervs workspace> -> "SSH keys" -> "Create SSH key" -> in the "key name" field, provide a desired name and paste the your public key in "Public key" field and click on "Add SSH key".
For more information related to creating ssh keys, please refer to [Creating SSH Keys](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-creating-ssh-key)

**Step J**: Create IBM Cloud Object Storage (COS)
<br> IBM Cloud Storage bucket is needed to hold the Oracle binaries.
1. Go to IBM Cloud dashboard, click on "Infrastructure" --> "Storage" --> "Object Storage"
2. Click on "Create Instance", this will open a new window, provide "Service name" and "tags". Click on "Create"/
3. After creation, click on "Create Bucket" and click on "Create a Custom Bucket" and enter the required fields and click on "Create bucket".
4. In the Cloud Object Instance, click on "Service Credentials" and click on "New Credential". Provide the "Name", set writer to the "Role" and click "Add".
5. Expand the credential and copy the contents.
Please refer to [Getting started with Cloud Object Storage](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-getting-started-cloud-object-storage)
Generate COS service credentials. Please refer to [COS Service Credentials](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-service-credentials)

**Step K**: Download the Oracle Binaries
1. Download Oracle Binaries from [Oracle Site](https://edelivery.oracle.com/osdc/faces/SoftwareDelivery) and Release Update(RU) system patches 19.X from [Oracle MOS](https://support.oracle.com).
   - RDBMS Base software: V982583-01_193000_db.zip
   - Grid Infrastructure software: V982588-01_193000_grid.zip
   - Download the latest System Patch (Release Update) 19.X containing both grid and rdbms RU patches for AIX from My Oracle Support. Refer to this MOS note [2521164.1](https://support.oracle.com/epmos/faces/DocumentDisplay?parent=DOCUMENT&sourceId=2521164.1&id=2521164.1) and also refer to this [Oracle documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/downloading-and-installing-patch-updates.html) to understand more on Oracle patch updates.
2. Upload the Oracle binaries to IBM Cloud COS bucket. Please refer to this documentation to upload the files.
[Upload data to COS Bucket](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-upload)

Example of "COS Oracle Software Storage Configuration" deployment input.

```
{
  "cos_bucket_name": "oracle-sw-123",
  "cos_oracle_cluvfy_file_path": "cvupack_aix_7_ppc64.zip",
  "cos_oracle_database_sw_path": "V982583-01_193000_db.zip",
  "cos_oracle_grid_sw_path": "V982588-01_193000_grid.zip",
  "cos_oracle_opatch_file_path": "p6880880_190000_AIX64-5L.zip",
  "cos_oracle_ru_file_path": "p37641958_190000_AIX64-5L.zip",
  "cos_region": "us-south"
}
```

**Step L**: Full Linux Subscription Implementation
- In Private environment, FLS setup is needed which is required for RHEL Subscription. This release of DA we will be using only IBM provided subscription images, refer to [FLS Documentation](https://www.ibm.com/docs/en/power-virtual-server?topic=linux-full-subscription-power-virtual-server-private-cloud) for more details.
- In Public environment, the RHEL Subscription is done at the time of VM creation automatically, and in DA we are not using any separate script for RHEL Subscription.

**Step M**: Whitelist schematic CIDR/IP
- At VPN Gateway or VPC VM level, whitelist the schematic CIDRs/IPs of region where schematic workspace gets created, refer to [Firewall Access – allowed IP addresses](https://cloud.ibm.com/docs/schematics?topic=schematics-allowed-ipaddresses)
- This step is optional if your using source as 0.0.0.0 under Security Group inbound rule for ssh connection

## Deployment Steps
### Deploy using projects
1. Go to IBM Cloud dashboard and create a new project. Refer to this link for more information about [Projects](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project)
2. Go to the catalog and search for oracle. Under community registry, select tile "Oracle on IBM Power Virtual Server".
3. In "Deployable architecture setup", select the project which was created in step 1.
4. Select the Architecture variation as "Oracle Database – Real Application Clusters (RAC)"
5. Click "Configure and deploy"
6. Edit and validate the configuration:
   1.	Enter values for required input fields
   2.	Review and update the optional inputs if needed
   3.	Save the configuration
   4.	Click Validate, validation takes a few minutes
   5.	Click Deploy (Deploying the deployable architecture can take more than 2 hours. You are notified when the deployment is successful)
   6.	Review the outputs from the deployable architecture

After Deployment Oracle RAC 19.X Multipurpose non-CDB Database will get created on 2 AIX nodes and JFS2 file system is created for archivelogs on each node. You can connect to the AIX VMs from VPN Gateway VM(VPC) or from gui console and verify the Oracle stack.

```
COMP_ID         COMP_NAME                                          STATUS
--------------- -------------------------------------------------- --------------------------------------------
CATALOG         Oracle Database Catalog Views                      VALID
CATPROC         Oracle Database Packages and Types                 VALID
RAC             Oracle Real Application Clusters                   VALID
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

## Oracle Real Application Clusters Deployable Architecture Inputs


|  Deployment Inputs   | Terraform Input Variable |     Description              | Values |
|------------------|----------------|-----------------------------------|----------------|
|     API Key      | ibmcloud_api_key |  IBM Cloud API key used to authenticate and provision resources. To generate an API key, see [Creating your IBM Cloud API key](https://www.ibm.com/docs/en/masv-and-l/cd?topic=cli-creating-your-cloud-api-key)|                |
| Deployment Type    | deployment_type| This solution provides both [PowerVS Public](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-getting-started) & [PowerVS Private](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-private-cloud-architecture) which can be controlled by this input variable.| Public or Private |
| Resource Name Prefix| prefix | Unique identifier prepended to all resources created by this template. |Use only lowercase letters with maximum 5 characters and allows only alpha-numeric and hyphen characters. Example: rac |
| Deployment Region| region | IBM Cloud region where resources will be deployed. See all available regions at [IBM Cloud locations](https://cloud.ibm.com/docs/overview?topic=overview-locations).| Example: Dallas |
| PowerVS Zone | zone | IBM Cloud data center zone within the region where IBM PowerVS infrastructure will be created (e.g., dal14, eu-de-1). See all available zones at [IBM PowerVS locations](https://www.ibm.com/docs/en/power-virtual-server?topic=locations-cloud-regions). For PowerVS Private we need to provide [Satellite Zone](https://www.ibm.com/docs/en/power-virtual-server?topic=locations-satellite-location) details. The zone can be retrieved from the workspace CRN, refer to "Step C" | Public: dal14      Private: satloc_dal_XXXX|
| PowerVS Workspace GUID | pi_existing_workspace_guid | GUID of an existing IBM Power Virtual Server Workspace. To find the GUID: IBM Cloud Console > Resource List > Compute > click the workspace > copy the GUID from the CRN, refer to "Step C". To create a new workspace, see [Creating an IBM Power Virtual Server](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-creating-power-virtual-server).| |
| Bastion Host IP Address | bastion_host_ip | Bastion host is a VPC vm hosted in IBM Cloud, Provide the [Floating IP address](https://cloud.ibm.com/docs/vpc?topic=vpc-fip-about) of the bastion host. | Example: 52.x.x.x |
| Bastion Host SSH Public Key Name | pi_ssh_public_key_name | Add bastion host's ssh public key to the PowerVS workspace. Provide this name as an input. To add an SSH key to the workspace, see [Managing IBM PowerVS SSH keys](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-creating-ssh-key). | Example: vpc_ssh_pubkey |
| Bastion Host SSH Private Key | ssh_private_key | RSA private SSH key corresponding to the public key referenced by 'pi_ssh_public_key_name'. Used to connect to IBM PowerVS instances during provisioning. The key is stored temporarily and deleted after use. To generate a key pair on the bastion host, run: ssh-keygen -t rsa, then copy the output of: cat ~/.ssh/id_rsa. For more information, see [SSH keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys).| n/a |
| VM Placement Policy | pi_replication_policy | PowerVS placement policy for Oracle RAC nodes. Controls how RAC nodes are distributed across physical hosts. Use 'anti-affinity' (Different Server) (recommended for RAC) to spread nodes across different hosts for high availability. Use 'affinity' (Same Server) to place nodes on the same host (not recommended for production RAC).For more information, see [Server Placement Group](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-managing-placement-groups)| Same Server / Different Server |
| PowerVS Networks | pi_networks | List of existing private subnet objects to attach to the instance. The first element becomes the primary network interface. Each object requires 'name' and 'id'. To list available subnets, run: ibmcloud pi networks. To create a subnet, see [Configuring a subnet](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-configuring-subnet). | For sample example refer to "Step D"|
| RHEL Management Server Type | pi_rhel_management_server_type | Server (machine) type for the RHEL management (Ansible controller) instance. To list available server types, run: ibmcloud pi server-types. | Example: s1022 |
| Squid - Proxy Server IP Address | squid_server_ip | Squid is configured on bastion host. Squid proxy IP refers to the Private IP on the bastion host which is used for communicating with PowerVS VSIs. It provides internet access to PowerVS VSIs required for downloading packages and patches during installation. To configure a Squid proxy server, see [Creating a proxy server](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-full-linux-sub#create-proxy-private). | Example: 10.x.x.x |
| RAC Cluster Name | cluster_name | Name for the Oracle RAC cluster. Used internally by Oracle Clusterware to identify the cluster. Must be unique within the domain and contain only alphanumeric characters and hyphens. For more information, see [Oracle Clusterware Administration](https://docs.oracle.com/en/database/oracle/oracle-database/19/cwadd/oracle-clusterware-administration.html) | Example: orac-cluster |
| Oracle Patch Version (RU) | ru_version | Oracle Release Update (RU) patch version to apply to both Grid Infrastructure and the Database. This must match the RU patch zip uploaded to the COS bucket at 'cos_oracle_ru_file_path'. Find available RU patches on [Oracle MOS note KB111276](https://support.oracle.com/epmos/faces/DocumentDisplay?id=2521164.1). | Example: 19.29 |
| Oracle Database Name (SID) | ora_sid | Oracle Database System Identifier (SID). A unique name for the Oracle database instance. Maximum 8 characters, alphanumeric, must start with a letter. For more information, see [Oracle Database Concepts](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/introduction-to-oracle-database.html). | Example: orcl |
| Oracle SYS Password | ora_db_password | Password for Oracle database administrative users (SYS, SYSTEM). Must meet Oracle password complexity requirements: minimum 8 characters, include at least one uppercase letter, one lowercase letter, and one number. |
| Cloud Object Storage(COS) Credentials | ibmcloud_cos_service_credentials | JSON service credentials for the IBM Cloud Object Storage instance used to access the COS bucket. To generate credentials: IBM Cloud Console > Cloud Object Storage > your instance > Service Credentials > New credential. See [COS Service Credentials](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-service-credentials) for a JSON example. | | #pragma: allowlist secret
| COS Oracle Software Storage Configuration | ibmcloud_cos_configuration | IBM Cloud Object Storage (COS) bucket details containing Oracle RAC installation binaries. Do not add a leading '/' to any path. Refer to "Step H" | Refer to "Step H" for sample example |
| AIX OS Image Name (Optional) | pi_aix_image_name | Name of the IBM PowerVS AIX boot image used to host the Oracle Database. Must be a valid AIX image available in the workspace. To list available images, run: ibmcloud pi images.| Example: 7300-04-00 |
| Number of RAC Nodes | rac_nodes | Number of Oracle RAC nodes to create. Minimum is 2 (required for RAC). All nodes will be provisioned with the same AIX image and instance configuration defined . For more information on Oracle RAC architecture, see [Oracle RAC Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/introduction-to-oracle-rac.html)." | 2
| Oracle Server Time Zone (Optional) | time_zone | Example: US Pacific (Los Angeles) |
| Cluster Domain Name (Optional) | cluster_domain | DNS domain name for the Oracle RAC cluster. Used to construct fully qualified hostnames for cluster nodes and the SCAN name. This domain must be resolvable within your network." | Example: example.com |
| AIX Instance Configuration(CPU,Mem) (Optional) | pi_aix_instance | Configuration for the IBM PowerVS AIX instance where Oracle Database will be installed. Fields: memory_gb (RAM in GB), cores (number of virtual processors), core_type (shared / capped / dedicated), machine_type (e.g., s1022 or e980), pin_policy (hard / soft), health_status (OK / Warning / Critical). | |
| Oracle Software Binary Disks (Optional) | pi_oravg_volume | Disk configuration for the Oracle software volume group (oravg). Fields: name (default: oravg), size (disk size in GB), count (number of disks), tier (storage tier, e.g., tier1 or tier3). | |
| Database Data Disks (Optional) | pi_data_volume | Disk configuration for the DATA. Used as the DATA diskgroup in ASM mode or as DATAVG in JFS2 mode. Fields: name (default: DATA), size (disk size in GB), count (number of disks), tier (storage tier, e.g., tier1 or tier3). |  |
| Redo Log Disks (Optional) | pi_redo_volume | Disk configuration for the REDO. Used as the REDO diskgroup in ASM mode or as REDOVG in JFS2 mode. Fields: name (default: REDO), size (disk size in GB), count (number of disks), tier (storage tier, e.g., tier1 or tier3). |  |
| Redo log member size (MB) (Optional) | redolog_size_in_mb | Size of each redo log member in megabytes (MB). Recommended minimum is 500 MB for production workloads. | Example: 1024 |
| Resource Tags (Optional) | pi_user_tags | List of tag names to apply to all IBM Cloud PowerVS instances and volumes created by this module. Can be set to null to skip tagging. | Example: ["oracledb"] |

## Help and Support
You can report issues and request features for this module in GitHub issues in the [repository link](https://github.com/terraform-ibm-modules/.github/blob/main/.github/SUPPORT.md)
