variable "deployment_type" {
  description = "Deployment type for the architecture. Accepted values: 'public' or 'private'."
  type        = string
  validation {
    condition     = contains(["public", "private"], var.deployment_type)
    error_message = "deployment_type must be either 'public' or 'private'"
  }
}

variable "ibmcloud_api_key" {
  description = "IBM Cloud API key used to authenticate and provision resources. To generate an API key, see [Creating your IBM Cloud API key](https://www.ibm.com/docs/en/masv-and-l/cd?topic=cli-creating-your-cloud-api-key)."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "IBM Cloud region where resources will be deployed (e.g., us-south, eu-de). See all available regions at [IBM Cloud locations](https://cloud.ibm.com/docs/overview?topic=overview-locations)."
  type        = string
}

variable "zone" {
  description = "IBM Cloud data center zone within the region where IBM PowerVS infrastructure will be created (e.g., dal14, eu-de-1). See all available zones at [IBM PowerVS locations](https://www.ibm.com/docs/en/power-virtual-server?topic=locations-cloud-regions)."
  type        = string
}

#####################################################
# Parameters IBM Cloud PowerVS Instance
#####################################################

variable "prefix" {
  description = "Unique identifier prepended to all resources created by this template. Use only lowercase letters the prefix shall be between 1 to 5 characters and allows only alpha-numeric and hyphen characters"
  type        = string
}

variable "pi_existing_workspace_guid" {
  description = "GUID of an existing IBM Power Virtual Server Workspace. To find the GUID: IBM Cloud Console > Resource List > Compute > click the workspace > copy the GUID from the CRN (the segment between the 7th and 8th colon). To create a new workspace, see [Creating an IBM Power Virtual Server](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-creating-power-virtual-server)."
  type        = string
}

variable "pi_ssh_public_key_name" {
  description = "Name of the existing SSH public key already uploaded to the PowerVS Workspace. To add an SSH key to the workspace, see [Managing IBM PowerVS SSH keys](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-creating-ssh-key)."
  type        = string
}

variable "ssh_private_key" {
  description = "RSA private SSH key corresponding to the public key referenced by 'pi_ssh_public_key_name'. Used to connect to IBM PowerVS instances during provisioning. The key is stored temporarily and deleted after use. To generate a key pair on the bastion host, run: ssh-keygen -t rsa, then copy the output of: cat ~/.ssh/id_rsa. For more information, see [SSH keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
  type        = string
  sensitive   = true
}

variable "pi_rhel_management_server_type" {
  description = "Server (machine) type for the RHEL management (Ansible controller) instance (e.g., s1022, e980). To list available server types, run: ibmcloud pi server-types."
  type        = string
}

variable "pi_rhel_image_name" {
  description = "Name of the IBM PowerVS RHEL boot image used for the Ansible controller instance. Must be a valid RHEL image available in the workspace. To list available images, run: ibmcloud pi images. For more information, see [Full Linux Subscription](https://www.ibm.com/docs/en/power-virtual-server?topic=linux-full-subscription-power-virtual-server-private-cloud)."
  type        = string
}

variable "pi_memory_size" {
  description = "Memory size in GB for the RHEL management instance."
  type        = string
  default     = "4"
}

variable "pi_aix_image_name" {
  description = "Name of the IBM PowerVS AIX boot image used to host the Oracle Database. Must be a valid AIX image available in the workspace. To list available images, run: ibmcloud pi images."
  type        = string
}

variable "pi_aix_instance" {
  description = "Configuration for the IBM PowerVS AIX instance where Oracle Database will be installed. Fields: memory_gb (RAM in GB), cores (number of virtual processors), core_type (shared | capped | dedicated), machine_type (e.g., s1022 or e980), pin_policy (hard | soft), health_status (OK | Warning | Critical)."
  type = object({
    memory_gb     = number
    cores         = optional(number)
    core_type     = string
    machine_type  = string
    pin_policy    = string
    health_status = string
  })
}

variable "pi_networks" {
  description = "List of existing private subnet objects to attach to the instance. The first element becomes the primary network interface. Each object requires 'name' and 'id'. To list available subnets, run: ibmcloud pi networks. To create a subnet, see [Configuring a subnet](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-configuring-subnet)."
  type = list(object({
    name = string
    id   = string
  }))
}

variable "ibmcloud_cos_configuration" {
  description = "IBM Cloud Object Storage (COS) bucket details containing Oracle installation binaries. 'cos_region': COS bucket region. 'cos_bucket_name': name of the COS bucket. 'cos_oracle_database_sw_path': folder path containing only the Oracle RDBMS binary (V982583-01_193000_db.zip). 'cos_oracle_grid_sw_path': folder path containing only the Oracle Grid binary (V982588-01_193000_grid.zip) — required for ASM only, leave empty for JFS. 'cos_oracle_ru_file_path': folder path containing only the RU patch zip. 'cos_oracle_opatch_file_path': folder path containing only the OPatch zip. Do not add a leading '/' to any path. Download Oracle binaries from [Oracle Software Delivery Cloud](https://edelivery.oracle.com/osdc/faces/SoftwareDelivery) and RU patches from [Oracle MOS (note 2521164.1)](https://support.oracle.com/epmos/faces/DocumentDisplay?id=2521164.1). To set up COS, see [Getting started with Cloud Object Storage](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-getting-started-cloud-object-storage) and [Uploading data to a COS bucket](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-upload)."
  type = object({
    cos_region                  = string
    cos_bucket_name             = string
    cos_oracle_database_sw_path = string
    cos_oracle_grid_sw_path     = optional(string)
    cos_oracle_ru_file_path     = string
    cos_oracle_opatch_file_path = string
  })
  validation {
    condition     = var.oracle_install_type == "ASM" ? (var.ibmcloud_cos_configuration.cos_oracle_grid_sw_path != null && length(var.ibmcloud_cos_configuration.cos_oracle_grid_sw_path) > 0) : true
    error_message = "For ASM installation, 'cos_oracle_grid_sw_path' must be provided in 'ibmcloud_cos_configuration'."
  }
}

variable "ibmcloud_cos_service_credentials" {
  description = "JSON service credentials for the IBM Cloud Object Storage instance used to access the COS bucket. To generate credentials: IBM Cloud Console > Cloud Object Storage > your instance > Service Credentials > New credential. See [COS Service Credentials](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-service-credentials) for a JSON example."
  type        = string
  sensitive   = true
}

#####################################################
# Oracle Storage Configuration
#####################################################

variable "pi_oravg_volume" {
  description = "Disk configuration for the Oracle software volume group (oravg). Fields: name (default: oravg), size (disk size in GB), count (number of disks), tier (storage tier, e.g., tier1 or tier3)."
  type = object({
    name  = optional(string, "oravg")
    size  = string
    count = string
    tier  = string
  })
}

variable "pi_data_volume" {
  description = "Disk configuration for the DATA volume. Used as the DATA diskgroup in ASM mode or as DATAVG in JFS2 mode. Fields: name (default: DATA), size (disk size in GB), count (number of disks), tier (storage tier, e.g., tier1 or tier3)."
  type = object({
    name  = optional(string, "DATA")
    size  = string
    count = string
    tier  = string
  })
}

variable "pi_redo_volume" {
  description = "Disk configuration for the REDO volume. Used as the REDO diskgroup in ASM mode or as REDOVG in JFS2 mode. Fields: name (default: REDO), size (disk size in GB), count (number of disks), tier (storage tier, e.g., tier1 or tier3)."
  type = object({
    name  = optional(string, "REDO")
    size  = string
    count = string
    tier  = string
  })
}

variable "redolog_size_in_mb" {
  description = "Size of each redo log member in megabytes (MB). Recommended minimum is 500 MB for production workloads."
  type        = string
}

############################################
# Optional IBM PowerVS Instance Parameters
############################################

variable "pi_user_tags" {
  description = "List of tag names to apply to all IBM Cloud PowerVS instances and volumes created by this module. Can be set to null to skip tagging."
  type        = list(string)
}

#####################################################
# Parameters Oracle Installation and Configuration
#####################################################

variable "bastion_host_ip" {
  description = "Public IP address of the bastion/jump host used to reach the Ansible controller (RHEL instance) in the private network. The bastion host must have the SSH private key at ~/.ssh/id_rsa. To set up a VPN gateway as the bastion host, contact IBM Support. For more information, see [IBM PowerVS Private Cloud Network Architecture](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-private-cloud-architecture#network-spec-private-cloud)."
  type        = string
}

variable "squid_server_ip" {
  description = "Private IP address of the Squid proxy server that provides internet access from within the private PowerVS network. Required for downloading packages and patches during installation. To configure a Squid proxy server, see [Creating a proxy server](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-full-linux-sub#create-proxy-private)."
  type        = string
}

variable "ora_sid" {
  description = "Oracle Database System Identifier (SID). A unique name for the Oracle database instance (e.g., ORCL). Maximum 8 characters, alphanumeric, must start with a letter. For more information, see [Oracle Database Concepts](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/introduction-to-oracle-database.html)."
  type        = string
}

variable "ora_db_password" {
  description = "Password for Oracle database administrative users (SYS, SYSTEM). Must meet Oracle password complexity requirements: minimum 8 characters, include at least one uppercase letter, one lowercase letter, and one number."
  type        = string
  sensitive   = true
}

variable "oracle_install_type" {
  description = "Oracle storage installation type. Use 'ASM' for Automatic Storage Management (requires Grid Infrastructure binaries in COS and 'cos_oracle_grid_sw_path' set) or 'JFS' for Journal File System (JFS2). ASM is recommended for production environments. "
  type        = string
}

variable "no_proxy_list" {
  description = "Comma-separated list of hostnames, IP addresses, or domains that should bypass the Squid proxy server. Default covers localhost only."
  type        = string
  default     = "localhost,127.0.0.1"
}
