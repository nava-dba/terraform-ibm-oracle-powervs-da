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
  description = "RSA private SSH key corresponding to the public key referenced by 'ssh_public_key'. Used to connect to IBM PowerVS instances during provisioning. The key is stored temporarily and deleted after use. To generate a key pair, run: ssh-keygen -t rsa. For more information, see [SSH keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
  type        = string
  sensitive   = true
}

variable "pi_aix_image_name" {
  description = "Name of the IBM PowerVS AIX boot image used to host the Oracle Database. Must be a valid AIX image available in the workspace. To list available images, run: ibmcloud pi images."
  type        = string
}

variable "pi_aix_instance" {
  description = "Configuration for the IBM PowerVS AIX instance where Oracle Database will be installed. Fields: memory_gb (RAM in GB, minimum 16GB), cores (number of virtual processors), core_type (shared | capped | dedicated), machine_type (e.g., s1022 or e980), pin_policy (hard | soft), health_status (OK | Warning | Critical)."
  type = object({
    memory_gb     = number
    cores         = optional(number)
    core_type     = string
    machine_type  = string
    pin_policy    = string
    health_status = string
  })

  validation {
    condition     = var.pi_aix_instance.memory_gb >= 16
    error_message = "AIX instance memory_gb must be at least 16GB. Current value: ${var.pi_aix_instance.memory_gb}GB"
  }

  validation {
    condition = (
      var.pi_aix_instance.cores == null ? true :
      var.pi_aix_instance.cores >= 0.25
    )
    error_message = "AIX instance cores must be at least 0.25. Current: ${coalesce(var.pi_aix_instance.cores, "not specified")}"
  }
}

variable "ibmcloud_cos_configuration" {
  description = "IBM Cloud Object Storage (COS) bucket details containing Oracle installation binaries. 'cos_region': COS bucket region. 'cos_bucket_name': name of the COS bucket. 'cos_oracle_database_sw_path': folder path containing only the Oracle RDBMS binary (V982583-01_193000_db.zip). 'cos_oracle_grid_sw_path': folder path containing only the Oracle Grid binary (V982588-01_193000_grid.zip) — required for ASM only, leave empty for JFS2. 'cos_oracle_ru_file_path': folder path containing only the RU patch zip. 'cos_oracle_opatch_file_path': folder path containing only the OPatch zip. Do not add a leading '/' to any path. Download Oracle binaries from [Oracle Software Delivery Cloud](https://edelivery.oracle.com/osdc/faces/SoftwareDelivery) and RU patches from [Oracle MOS (note 2521164.1)](https://support.oracle.com/epmos/faces/DocumentDisplay?id=2521164.1). To set up COS, see [Getting started with Cloud Object Storage](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-getting-started-cloud-object-storage) and [Uploading data to a COS bucket](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-upload)."
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

  validation {
    condition     = tonumber(var.pi_oravg_volume.size) * tonumber(var.pi_oravg_volume.count) >= 120
    error_message = "Total Oracle Binary disk filesystem size (size * count) must be at least 120GB. Current: ${var.pi_oravg_volume.size}GB * ${var.pi_oravg_volume.count} = ${tonumber(var.pi_oravg_volume.size) * tonumber(var.pi_oravg_volume.count)}GB"
  }
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
  description = "List of tag names to apply to all IBM Cloud resources created (PowerVS and VPC). Used for cost tracking and resource organization."
  type        = list(string)
}

#####################################################
# Parameters Oracle Installation and Configuration
#####################################################

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
  description = "Oracle storage installation type. Use 'ASM' for Automatic Storage Management (requires Grid Infrastructure binaries in COS and 'cos_oracle_grid_sw_path' set) or 'JFS2' for Journal File System (JFS2). ASM is recommended for production environments. "
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

variable "powervs_oracle_network_cidr" {
  description = "Network range for dedicated Oracle network. Used for Oracle Database communication. E.g., '10.51.0.0/24'"
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
