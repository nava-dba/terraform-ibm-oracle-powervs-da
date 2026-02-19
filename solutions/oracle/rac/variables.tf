variable "deployment_type" {
  description = "Deployment type: public or private"
  type        = string
  validation {
    condition     = contains(["public", "private"], var.deployment_type)
    error_message = "deployment_type must be either 'public' or 'private'"
  }
}


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
  description = "A unique identifier for resources. Must contain only lowercase letters, numbers, and - characters. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
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

variable "pi_memory_size" {
  description = "Memory size in GB for RHEL."
  type        = string
  default     = "4"
}

variable "pi_aix_image_name" {
  description = "Name of the IBM PowerVS AIX boot image used to deploy and host Oracle Database Appliance."
  type        = string
}

variable "pi_aix_instance" {
  description = "Configuration settings for the IBM PowerVS AIX instance where Oracle will be installed. Includes memory size, number of processors, processor type, and system type."

  type = object({
    memory_gb     = number           # Memory size in GB
    cores         = optional(number) # Number of virtual processors
    core_type     = string           # Processor type: shared, capped, or dedicated
    machine_type  = string           # System type (e.g., s922, e980)
    pin_policy    = string           # Pin policy (e.g., hard, soft)
    health_status = string           # Health status (e.g., OK, Warning, Critical)
  })
}

variable "pi_replication_policy" {
  description = <<-EOT
    PowerVS replication (placement) policy for replicated AIX instances.

    Recommended for Oracle RAC:
    - anti-affinity (DEFAULT): Spread RAC nodes across different hosts for high availability.
    - affinity: Place nodes on the same host (NOT recommended for RAC).
    - none: No placement policy (risk of co-location).

    Best practice for Oracle RAC is "anti-affinity".
  EOT

  type    = string
  default = "anti-affinity"

  validation {
    condition = contains(
      ["anti-affinity", "affinity", "none"],
      var.pi_replication_policy
    )
    error_message = "pi_replication_policy must be one of: anti-affinity, affinity, or none."
  }
}


###########################################################
# Network Configuration
###########################################################
variable "pi_networks" {
  description = <<-EOT
    Existing list of private subnet ids to be attached to an instance. The first element will become the primary interface. Run 'ibmcloud pi networks' to list available private subnets
    Networks for AIX instances in order: [0]=management, [1]=public, [2]=private1, [3]=private2.
    Users must provide networks in this specific order:
    - Index 0: Management/Control network
    - Index 1: Public network (for client connections)
    - Index 2: Private interconnect 1 (for RAC heartbeat)
    - Index 3: Private interconnect 2 (for RAC heartbeat)
  EOT
  type = list(object({
    name = string
    id   = string
  }))

  validation {
    condition     = length(var.pi_networks) >= 4
    error_message = "At least 4 networks are required: management, public, private1, and private2."
  }
}

variable "aix_network_interfaces" {
  description = "Network interface names on AIX instances"
  type = object({
    public   = string
    private1 = string
    private2 = string
  })
  default = {
    public   = "en1"
    private1 = "en2"
    private2 = "en3"
  }
}

variable "no_proxy_list" {
  description = "Comma-separated list of hosts/domains to exclude from proxy"
  type        = string
  default     = "localhost,127.0.0.1"
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
    cos_oracle_cluvfy_file_path = optional(string)
  })
}

variable "ibmcloud_cos_service_credentials" {
  description = "IBM Cloud Object Storage instance service credentials to access the bucket in the instance (IBM Cloud > Cloud Object Storage > Instances > cos-instance-name > Service Credentials).[json example of service credential](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-service-credentials)"
  type        = string
  sensitive   = true
}

#####################################################
# Oracle Storage Configuration
#####################################################

# 1. oravg
variable "pi_oravg_volume" {
  description = "ORAVG volume configuration"
  type = object({
    name  = optional(string, "oravg")
    size  = string
    count = string
    tier  = string
  })
}

# 2. DATA diskgroup
variable "pi_data_volume" {
  description = "Disk configuration for ASM"
  type = object({
    name  = optional(string, "DATA")
    size  = string
    count = string
    tier  = string
  })
}

# 3. REDO diskgroup
variable "pi_redo_volume" {
  description = "Disk configuration for ASM"
  type = object({
    name  = optional(string, "REDO")
    size  = string
    count = string
    tier  = string
  })
}

variable "redolog_size_in_mb" {
  description = "Redo log member size in MB."
  type        = string
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
  description = "Squid server IP address to reach the internet from private network."
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

#####################################################
# RAC Params
#####################################################
variable "rac_nodes" {
  description = "Number of RAC nodes to create"
  type        = number
  default     = 2

  validation {
    condition     = var.rac_nodes >= 2
    error_message = "At least 2 nodes are required for RAC configuration."
  }
}

variable "root_password" {
  description = "Root password for the Oracle RAC AIX virtual server instance."
  type        = string
  sensitive   = true
}

variable "time_zone" {
  description = "Time zone to configure on the Oracle RAC virtual server instance. Example: UTC, America/New_York."
  type        = string
  default     = "America/Los_Angeles"
}


variable "scan_name" {
  description = "SCAN (Single Client Access Name) hostname"
  type        = string
  default     = "orac-scan"
}

# ===========================
# Database Configuration
# ===========================

variable "ru_version" {
  description = "Oracle grid and database RU patch version."
  type        = string
}

variable "cluster_domain" {
  description = "Specify the cluster domain example.com"
  type        = string
}


variable "cluster_name" {
  description = "Specify the cluster namen example orac-cluster"
  type        = string
}
