variable "ibmcloud_api_key" {
  description = "API Key of IBM Cloud Account."
  type        = string
  sensitive   = true
}

variable "region" {
  type        = string
  description = "The IBM Cloud region to deploy resources."
}

variable "zone" {
  description = "The IBM Cloud zone to deploy the PowerVS instance."
  type        = string
}

#####################################################
# Parameters IBM Cloud PowerVS Instance
#####################################################
variable "prefix" {
  description = "A unique identifier for resources. Must contain only lowercase letters, numbers, and - characters. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 5 or fewer characters."
  type        = string
}

variable "pi_existing_workspace_guid" {
  description = "Existing Power Virtual Server Workspace GUID."
  type        = string
}

variable "pi_ssh_public_key_name" {
  description = "Name of the SSH key pair to associate with the instance"
  type        = string
}

variable "ssh_private_key" {
  description = "Private SSH key (RSA format) used to login to IBM PowerVS instances. Should match to uploaded public SSH key referenced by 'pi_ssh_public_key_name' which was created previously. The key is temporarily stored and deleted. For more information about SSH keys, see [SSH keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
  type        = string
  sensitive   = true
}

variable "pi_rhel_management_server_type" {
  description = "Server type for the management instance."
  type        = string
}

variable "pi_rhel_image_name" {
  description = "Name of the IBM PowerVS RHEL boot image to use for provisioning the instance. Must reference a valid RHEL image."
  type        = string
}

variable "pi_aix_image_name" {
  description = "Name of the IBM PowerVS AIX boot image used to deploy and host Oracle Database Appliance."
  type        = string
}

variable "pi_aix_instance" {
  description = "Configuration settings for the IBM PowerVS AIX instance where Oracle will be installed. Includes memory size, number of processors, processor type, and system type."

  type = object({
    memory_size       = number # Memory size in GB
    number_processors = number # Number of virtual processors
    cpu_proc_type     = string # Processor type: shared, capped, or dedicated
    server_type       = string # System type (e.g., s1022, e980)
    pin_policy        = string # Pin policy (e.g., hard, soft)
    health_status     = string # Health status (e.g., OK, Warning, Critical)
  })
}

variable "pi_networks" {
  description = "Existing list of private subnet ids to be attached to an instance. The first element will become the primary interface. Run 'ibmcloud pi networks' to list available private subnets."
  type = list(object({
    name = string
    id   = string
  }))
}


variable "ibmcloud_cos_configuration" {
  description = "Cloud Object Storage instance containing Oracle installation files that will be downloaded to NFS share. 'db-sw/cos_oracle_database_sw_path' must contain only binaries required for Oracle Database installation. 'grid-sw/cos_oracle_grid_sw_path' must contain only binaries required for oracle grid installation when ASM. Leave it empty when JFS. 'patch/cos_oracle_ru_file_path' must contain only binaries required to apply RU patch.'opatch/cos_oracle_opatch_file_path' must contain only binaries required for opatch minimum version install. The binaries required for installation can be found [here](https://edelivery.oracle.com/osdc/faces/SoftwareDelivery or https://www.oracle.com/database/technologies/oracle19c-aix-193000-downloads.html).Avoid inserting '/' at the beginning for 'cos_oracle_database_sw_path', 'cos_oracle_grid_sw_path' and 'cos_oracle_ru_file_path', and 'cos_oracle_opatch_file_path'. Follow exactly same directory structure as prescribed"
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
  description = "IBM Cloud Object Storage instance service credentials to access the bucket in the instance (IBM Cloud > Cloud Object Storage > Instances > cos-instance-name > Service Credentials).[json example of service credential](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-service-credentials)"
  type        = string
  sensitive   = true
}

#####################################################
# Oracle Storage Configuration
#####################################################

# 1. rootvg
variable "pi_boot_volume" {
  description = "Boot volume configuration"
  type = object({
    name  = string
    size  = string
    count = string
    tier  = string
  })
  default = {
    "name" : "rootvg",
    "size" : "40",
    "count" : "1",
    "tier" : "tier1"
  }
}

# 2. oravg
variable "pi_oravg_volume" {
  description = "ORAVG volume configuration"
  type = object({
    name  = optional(string, "oravg")
    size  = string
    count = string
    tier  = string
  })
}

# 3. CRSDG diskgroup
variable "pi_crsdg_volume" {
  description = "Disk configuration for ASM"
  type = object({
    name  = string
    size  = string
    count = string
    tier  = string
  })
  default = {
    "name" : "CRSDG",
    "size" : "8",
    "count" : "4",
    "tier" : "tier1"
  }
}

# 4. DATA diskgroup
variable "pi_data_volume" {
  description = "Disk configuration for ASM"
  type = object({
    name  = optional(string, "DATA")
    size  = string
    count = string
    tier  = string
  })
}

# 5. REDO diskgroup
variable "pi_redo_volume" {
  description = "Disk configuration for ASM"
  type = object({
    name  = optional(string, "REDO")
    size  = string
    count = string
    tier  = string
  })
}

# 6. oradatavg
variable "pi_datavg_volume" {
  description = "Disk configuration for ASM"
  type = object({
    name  = optional(string, "datavg")
    size  = string
    count = string
    tier  = string
  })
}

############################################
# Optional IBM PowerVS Instance Parameters
############################################
variable "pi_user_tags" {
  description = "List of Tag names for IBM Cloud PowerVS instance and volumes. Can be set to null."
  type        = list(string)
}


#####################################################
# Parameters Oracle Installation and Configuration
#####################################################

variable "bastion_host_ip" {
  description = "Jump/Bastion server public IP address to reach the ansible host which has private IP."
  type        = string
}

variable "squid_server_ip" {
  description = "Squid server IP address to reach the internet from private network, mandatory if private cloud is targeted"
  type        = string
}

variable "ora_sid" {
  description = "Name for the oracle database DB SID."
  type        = string
}

variable "ora_db_password" {
  description = "Oracle DB user password"
  type        = string
  sensitive   = true
}

variable "oracle_install_type" {
  description = "Oracle install type, value would be either ASM or JFS"
  type        = string
}

variable "skip_validation" {
  description = "Skip pre-deployment validation checks if set to true."
  type        = bool
  default     = false
}
