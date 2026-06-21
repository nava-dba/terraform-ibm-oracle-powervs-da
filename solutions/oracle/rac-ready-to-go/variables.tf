########################################################
# IBM Cloud Authentication
########################################################

variable "ibmcloud_api_key" {
  description = "IBM Cloud API key used to authenticate and provision resources. To generate an API key, see [Creating your IBM Cloud API key](https://www.ibm.com/docs/en/masv-and-l/cd?topic=cli-creating-your-cloud-api-key)."
  type        = string
  sensitive   = true
}

#####################################################
# Parameters IBM Cloud PowerVS Instance
#####################################################

variable "prefix" {
  description = "Unique identifier prepended to all resources created by this template. Use only lowercase letters the prefix shall be between 1 to 5 characters and allows only alpha-numeric and hyphen characters"
  type        = string
}

variable "ssh_public_key" {
  description = "Public SSH Key for VSI creation. Must be an RSA key with a key size of either 2048 bits or 4096 bits (recommended). Must be a valid SSH key that does not already exist in the deployment region."
  type        = string
}

variable "ssh_private_key" {
  description = "RSA private SSH key corresponding to the public key referenced by 'pi_ssh_public_key_name'. Used to connect to IBM PowerVS instances during provisioning. The key is stored temporarily and deleted after use. To generate a key pair on the bastion host, run: ssh-keygen -t rsa, then copy the output of: cat ~/.ssh/id_rsa. For more information, see [SSH keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
  type        = string
  sensitive   = true
}

variable "pi_aix_image_name" {
  description = "Name of the IBM PowerVS AIX boot image used to host the Oracle Database. Must be a valid AIX image available in the workspace. To list available images, run: ibmcloud pi images."
  type        = string
}

variable "pi_aix_instance" {
  description = "Configuration for the IBM PowerVS AIX instance where Oracle RAC will be installed. This configuration is applied to each RAC node. Fields: memory_gb (RAM in GB, minimum 24GB), cores (number of virtual processors), core_type (shared | capped | dedicated), machine_type (e.g., s1022 or e980), pin_policy (hard | soft), health_status (OK | Warning | Critical)."
  type = object({
    memory_gb     = number
    cores         = optional(number)
    core_type     = string
    machine_type  = string
    pin_policy    = string
    health_status = string
  })

  validation {
    condition     = var.pi_aix_instance.memory_gb >= 24
    error_message = "AIX instance memory_gb must be at least 24GB. Current value: ${var.pi_aix_instance.memory_gb}GB"
  }

  validation {
    condition = (
      var.pi_aix_instance.cores == null ? true :
      var.pi_aix_instance.cores >= 0.25
    )
    error_message = "AIX RAC instance cores must be at least 0.25. Current: ${coalesce(var.pi_aix_instance.cores, "not specified")}"
  }
}

variable "pi_replication_policy" {
  description = "PowerVS placement (replication) policy for Oracle RAC nodes. Controls how RAC nodes are distributed across physical hosts. Use 'anti-affinity' (recommended for RAC) to spread nodes across different hosts for high availability. Use 'affinity' to place nodes on the same host (not recommended for production RAC). Use 'none' to apply no placement constraint."
  type        = string
  default     = "anti-affinity"

  validation {
    condition     = contains(["anti-affinity", "affinity", "none"], var.pi_replication_policy)
    error_message = "pi_replication_policy must be one of: anti-affinity, affinity, or none."
  }
}

variable "ibmcloud_cos_configuration" {
  description = "IBM Cloud Object Storage (COS) bucket details containing Oracle RAC installation binaries. 'cos_region': COS bucket region. 'cos_bucket_name': name of the COS bucket. 'cos_oracle_database_sw_path': folder path containing only the Oracle RDBMS binary (V982583-01_193000_db.zip). 'cos_oracle_grid_sw_path': folder path containing only the Oracle Grid Infrastructure binary (V982588-01_193000_grid.zip) — required for RAC as ASM is mandatory. 'cos_oracle_ru_file_path': folder path containing only the RU patch zip. 'cos_oracle_opatch_file_path': folder path containing only the OPatch zip. 'cos_oracle_cluvfy_file_path': folder path containing the Oracle Cluster Verification Utility (cluvfy) zip — used to validate the RAC cluster pre-installation requirements. Do not add a leading '/' to any path. Download Oracle binaries from [Oracle Software Delivery Cloud](https://edelivery.oracle.com/osdc/faces/SoftwareDelivery) and RU patches from [Oracle MOS (note 2521164.1)](https://support.oracle.com/epmos/faces/DocumentDisplay?id=2521164.1). . To set up COS, see [Getting started with Cloud Object Storage](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-getting-started-cloud-object-storage) and [Uploading data to a COS bucket](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-upload)."
  type = object({
    cos_region                  = string
    cos_bucket_name             = string
    cos_oracle_database_sw_path = string
    cos_oracle_grid_sw_path     = optional(string)
    cos_oracle_ru_file_path     = string
    cos_oracle_opatch_file_path = string
    cos_oracle_cluvfy_file_path = optional(string)
  })
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

  validation {
    condition     = tonumber(var.pi_oravg_volume.size) * tonumber(var.pi_oravg_volume.count) >= 120
    error_message = "Total Oracle Binary disk filesystem size (size * count) must be at least 120GB. Current: ${var.pi_oravg_volume.size}GB * ${var.pi_oravg_volume.count} = ${tonumber(var.pi_oravg_volume.size) * tonumber(var.pi_oravg_volume.count)}GB"
  }
}

variable "pi_data_volume" {
  description = "Disk configuration for the DATA ASM diskgroup shared across all RAC nodes. Fields: name (default: DATA), size (disk size in GB), count (number of disks), tier (storage tier, e.g., tier1 or tier3)."
  type = object({
    name  = optional(string, "DATA")
    size  = string
    count = string
    tier  = string
  })
}

variable "pi_redo_volume" {
  description = "Disk configuration for the REDO ASM diskgroup shared across all RAC nodes. Fields: name (default: REDO), size (disk size in GB), count (number of disks), tier (storage tier, e.g., tier1 or tier3)."
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
  description = "List of tag names to apply to all IBM Cloud PowerVS instances and volumes created by this module. Cannot be null and use proper format."
  type        = list(string)
}

#####################################################
# Parameters Oracle Installation and Configuration
#####################################################

variable "ora_sid" {
  description = "Oracle Database System Identifier (SID). A unique name for the Oracle RAC database instance (e.g., ORCL). For RAC, this is also used as the database unique name prefix across all nodes. Maximum 8 characters, alphanumeric, must start with a letter. For more information, see [Oracle Database Concepts](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/introduction-to-oracle-database.html)."
  type        = string
}

variable "ora_db_password" {
  description = "Password for Oracle database administrative users (SYS, SYSTEM). Must meet Oracle password complexity requirements: minimum 8 characters, include at least one uppercase letter, one lowercase letter, and one number."
  type        = string
  sensitive   = true
}

#####################################################
# RAC Parameters
#####################################################

variable "rac_nodes" {
  description = "Number of Oracle RAC nodes to create. Minimum is 2 (required for RAC). All nodes will be provisioned with the same AIX image and instance configuration defined . For more information on Oracle RAC architecture, see [Oracle RAC Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/introduction-to-oracle-rac.html)."
  type        = number
  default     = 2

  validation {
    condition     = var.rac_nodes >= 2
    error_message = "At least 2 nodes are required for RAC configuration."
  }
}

variable "root_password" {
  description = "Root user password for all Oracle RAC AIX virtual server instances. This password is set on each RAC node during provisioning and is required for administrative access.The specified value should be alpha-numeric and shall contain at least 1 upper, 1 lower, 1 digit and a special character,the specified value length should be between 8 and 30 characters."
  type        = string
  sensitive   = true
}

variable "time_zone" {
  description = "Time zone to configure on all Oracle RAC AIX virtual server instances (e.g., UTC, America/New_York, America/Los_Angeles). All RAC nodes must use the same time zone."
  type        = string
  default     = "America/Los_Angeles"
}
# ===========================
# Database Configuration
# ===========================

variable "ru_version" {
  description = "Oracle Release Update (RU) patch version to apply to both Grid Infrastructure and the Database (e.g., 19.20.0.0). This must match the RU patch zip uploaded to the COS bucket at 'cos_oracle_ru_file_path'. Find available RU patches on [Oracle MOS (note 2521164.1)](https://support.oracle.com/epmos/faces/DocumentDisplay?id=2521164.1)."
  type        = string
}

variable "cluster_domain" {
  description = "DNS domain name for the Oracle RAC cluster (e.g., example.com). Used to construct fully qualified hostnames for cluster nodes and the SCAN name. This domain must be resolvable within your network."
  type        = string
}

variable "cluster_name" {
  description = "Name for the Oracle RAC cluster (e.g., orac-cluster). Used internally by Oracle Clusterware to identify the cluster. Must be unique within the domain and contain only alphanumeric characters and hyphens. For more information, see [Oracle Clusterware Administration](https://docs.oracle.com/en/database/oracle/oracle-database/19/cwadd/oracle-clusterware-administration.html)."
  type        = string
}

#####################################################
# Ready-to-Go Specific Parameters
#####################################################

variable "powervs_zone" {
  description = "IBM Cloud data center location where IBM PowerVS infrastructure will be created."
  type        = string
}

variable "powervs_resource_group_name" {
  description = "Existing IBM Cloud resource group name."
  type        = string
}

variable "powervs_management_network_cidr" {
  description = "Network CIDR for PowerVS management network (e.g., '10.51.0.0/24')."
  type        = string
  default     = "10.51.0.0/24"
}

variable "external_access_ip" {
  description = "Specify the IP address or CIDR to login through SSH to the environment after deployment. Access to this environment will be allowed only from this IP address."
  type        = string
}

variable "nfs_server_config" {
  description = "Configuration for the NFS server. 'size' is in GB, 'iops' is maximum input/output operation performance bandwidth per second, 'mount_path' defines the target mount point on os. Set 'configure_nfs_server' to false to ignore creating file storage share."
  type = object({
    size       = number
    iops       = number
    mount_path = string
  })

  default = {
    "size" : 200,
    "iops" : 600,
    "mount_path" : "/nfs"
  }
}

variable "vpc_intel_images" {
  description = "Stock OS image names for creating VPC landing zone VSI instances: RHEL (management and network services) and SLES (monitoring)."
  type = object({
    rhel_image = string
    sles_image = string
  })
  default = {
    "rhel_image" : "ibm-redhat-9-4-amd64-sap-applications-5"
    "sles_image" : "ibm-sles-15-6-amd64-sap-applications-3"
  }
}

#####################################################
# Optional Parameters VPN and Secrets Manager
#####################################################

variable "client_to_site_vpn" {
  description = "VPN configuration - the client ip pool and list of users email ids to access the environment. If enabled, then a Secret Manager instance is also provisioned with certificates generated. See optional parameters to reuse an existing Secrets manager instance."
  type = object({
    enable                        = bool
    client_ip_pool                = string
    vpn_client_access_group_users = list(string)
  })

  default = {
    "enable" : false,
    "client_ip_pool" : "192.168.0.0/16",
    "vpn_client_access_group_users" : []
  }
}

variable "sm_service_plan" {
  type        = string
  description = "The service/pricing plan to use when provisioning a new Secrets Manager instance. Allowed values: `standard` and `trial`. Only used if `existing_sm_instance_guid` is set to null."
  default     = "standard"
}

variable "existing_sm_instance_guid" {
  type        = string
  description = "An existing Secrets Manager GUID. If not provided a new instance will be provisioned."
  default     = null
}

variable "existing_sm_instance_region" {
  type        = string
  description = "Required if value is passed into `var.existing_sm_instance_guid`."
  default     = null

}

#####################################################
# Optional Parameters VPC subnets
#####################################################

variable "vpc_subnet_cidrs" {
  description = "CIDR values for the VPC subnets to be created. It's customer responsibility that none of the defined networks collide, including the PowerVS subnets and VPN client pool."
  type = object({
    vpn  = string
    mgmt = string
    vpe  = string
    edge = string
  })
  default = {
    "vpn"  = "10.10.10.0/24"
    "mgmt" = "10.20.10.0/24"
    "vpe"  = "10.30.10.0/24"
    "edge" = "10.40.10.0/24"
  }
}
