########################################################
# IBM Cloud Authentication
########################################################

variable "ibmcloud_api_key" {
  description = "IBM Cloud API key used to authenticate and provision resources."
  type        = string
  sensitive   = true
}

########################################################
# PowerVS Zone and Resource Group
########################################################

variable "powervs_zone" {
  description = "IBM Cloud data center location where IBM PowerVS infrastructure will be created (e.g., dal10, lon04, syd04, tok04)."
  type        = string
}

variable "powervs_resource_group_name" {
  description = "Existing IBM Cloud resource group name."
  type        = string
  default     = "Default"
}

variable "prefix" {
  description = "Unique identifier prepended to all resources. Must be lowercase alphanumeric, max 8 characters."
  type        = string
  validation {
    condition = (
      var.prefix != null &&
      var.prefix != "" &&
      length(var.prefix) <= 8 &&
      can(regex("^[a-z0-9-]+$", var.prefix))
    )
    error_message = "Prefix must be up to 8 characters long and may include lowercase letters, numbers, and hyphens only."
  }
}

variable "tags" {
  description = "List of tags to apply to all resources."
  type        = list(string)
  default     = []
}

########################################################
# Network Configuration
########################################################

variable "powervs_management_network_cidr" {
  description = "Network CIDR for PowerVS management network (e.g., '10.51.0.0/24')."
  type        = string
  default     = "10.51.0.0/24"
}

variable "powervs_rac_networks" {
  description = "List of 3 pre-created PowerVS networks for RAC in order: [0]=public (client connections), [1]=private1 (interconnect), [2]=private2 (interconnect). Each must have 'name', 'id', and 'cidr'."
  type = list(object({
    name = string
    id   = string
    cidr = string
  }))

  validation {
    condition     = length(var.powervs_rac_networks) == 3
    error_message = "Exactly 3 RAC networks required: public, private1, private2."
  }
}

variable "external_access_ip" {
  description = "Source IP address or CIDR for SSH access to the environment. Set to '0.0.0.0/0' to allow from anywhere (not recommended for production)."
  type        = string
  default     = "0.0.0.0/0"
}

########################################################
# SSH Keys
########################################################

variable "ssh_public_key" {
  description = "Public SSH key (RSA format) for VSI creation. Must be a valid RSA key with 2048 or 4096 bits."
  type        = string
}

variable "ssh_private_key" {
  description = "Private SSH key (RSA format) corresponding to ssh_public_key. Used for remote connections during provisioning."
  type        = string
  sensitive   = true
}

########################################################
# VPC Intel Images
########################################################

variable "vpc_intel_images" {
  description = "Stock OS image names for VPC VSI instances (RHEL for management/network services, SLES for monitoring)."
  type = object({
    rhel_image = string
    sles_image = string
  })
  default = {
    rhel_image = "ibm-redhat-9-4-amd64-sap-applications-5"
    sles_image = "ibm-sles-15-6-amd64-sap-applications-3"
  }
}

########################################################
# Oracle RAC Cluster Configuration
########################################################

variable "rac_node_count" {
  description = "Number of nodes in the Oracle RAC cluster (2-8 nodes)."
  type        = number
  default     = 2

  validation {
    condition     = var.rac_node_count >= 2 && var.rac_node_count <= 8
    error_message = "RAC cluster must have between 2 and 8 nodes."
  }
}

variable "pi_replication_policy" {
  description = "PowerVS placement policy for RAC nodes. Use 'anti-affinity' (recommended) to spread nodes across hosts for HA."
  type        = string
  default     = "anti-affinity"

  validation {
    condition     = contains(["anti-affinity", "affinity", "none"], var.pi_replication_policy)
    error_message = "pi_replication_policy must be: anti-affinity, affinity, or none."
  }
}

########################################################
# PowerVS AIX Instance Configuration
########################################################

variable "powervs_aix_image_name" {
  description = "Name of the AIX boot image for Oracle RAC instances. Must exist in the PowerVS workspace."
  type        = string
}

variable "powervs_aix_instance" {
  description = "Configuration for each PowerVS AIX RAC node."
  type = object({
    memory_gb    = number
    cores        = number
    core_type    = string
    machine_type = string
    pin_policy   = string
  })

  validation {
    condition     = var.powervs_aix_instance.memory_gb >= 24
    error_message = "Each RAC node must have at least 24GB memory."
  }

  validation {
    condition     = var.powervs_aix_instance.cores >= 0.25
    error_message = "Each RAC node must have at least 0.25 cores."
  }

  validation {
    condition     = contains(["shared", "capped", "dedicated"], var.powervs_aix_instance.core_type)
    error_message = "core_type must be one of: shared, capped, dedicated."
  }

  validation {
    condition     = contains(["none", "soft", "hard"], var.powervs_aix_instance.pin_policy)
    error_message = "pin_policy must be one of: none, soft, hard."
  }
}

########################################################
# Oracle Storage Configuration (ASM is mandatory for RAC)
########################################################

variable "powervs_oravg_volume" {
  description = "Storage configuration for Oracle software volume group."
  type = object({
    size  = string
    count = string
    tier  = string
  })
  default = {
    size  = "50"
    count = "1"
    tier  = "tier3"
  }
}

variable "powervs_data_volume" {
  description = "Storage configuration for Oracle DATA ASM diskgroup."
  type = object({
    size  = string
    count = string
    tier  = string
  })
  default = {
    size  = "100"
    count = "2"
    tier  = "tier1"
  }
}

variable "powervs_redo_volume" {
  description = "Storage configuration for Oracle REDO ASM diskgroup."
  type = object({
    size  = string
    count = string
    tier  = string
  })
  default = {
    size  = "50"
    count = "2"
    tier  = "tier1"
  }
}

########################################################
# Oracle Database Configuration
########################################################

variable "oracle_sid" {
  description = "Oracle System Identifier (SID) for the RAC database. Must be alphanumeric, max 8 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9]{0,7}$", var.oracle_sid))
    error_message = "Oracle SID must start with a letter, be alphanumeric, and max 8 characters."
  }
}

variable "oracle_db_password" {
  description = "Password for Oracle Database SYS and SYSTEM users. Must meet Oracle password requirements."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.oracle_db_password) >= 8
    error_message = "Oracle database password must be at least 8 characters long."
  }
}

variable "oracle_redolog_size_in_mb" {
  description = "Size of Oracle redo log files in MB."
  type        = number
  default     = 512

  validation {
    condition     = var.oracle_redolog_size_in_mb >= 100
    error_message = "Redo log size must be at least 100MB."
  }
}

########################################################
# IBM Cloud Object Storage (COS) Configuration
########################################################

variable "ibmcloud_cos_service_credentials" {
  description = "IBM Cloud Object Storage service credentials in JSON format. Must include 'apikey' and 'resource_instance_id'."
  type        = string
  sensitive   = true
}

variable "ibmcloud_cos_configuration" {
  description = "IBM Cloud Object Storage configuration for Oracle RAC binaries."
  type = object({
    cos_region                  = string
    cos_bucket_name             = string
    cos_oracle_database_sw_path = string
    cos_oracle_grid_sw_path     = string
    cos_oracle_ru_file_path     = string
    cos_oracle_opatch_file_path = string
    cos_oracle_cluvfy_file_path = optional(string)
  })
}

########################################################
# Network Services Configuration
########################################################

variable "nfs_server_config" {
  description = "NFS server configuration for shared storage."
  type = object({
    size       = number
    iops       = number
    mount_path = string
  })
  default = {
    size       = 200
    iops       = 600
    mount_path = "/nfs"
  }
}

########################################################
# Optional: Client-to-Site VPN
########################################################

variable "client_to_site_vpn" {
  description = "VPN configuration for client access to the environment."
  type = object({
    enable                        = bool
    client_ip_pool                = string
    vpn_client_access_group_users = list(string)
  })
  default = {
    enable                        = false
    client_ip_pool                = "192.168.0.0/16"
    vpn_client_access_group_users = []
  }
}

variable "sm_service_plan" {
  description = "Service plan for Secrets Manager instance (required if VPN is enabled)."
  type        = string
  default     = "standard"
}

variable "existing_sm_instance_guid" {
  description = "GUID of existing Secrets Manager instance. If null, a new instance will be created when VPN is enabled."
  type        = string
  default     = null
}

variable "existing_sm_instance_region" {
  description = "Region of existing Secrets Manager instance. Required if existing_sm_instance_guid is provided."
  type        = string
  default     = null
}

########################################################
# Optional: Monitoring
########################################################

variable "enable_monitoring" {
  description = "Enable IBM Cloud Monitoring and create monitoring host VSI."
  type        = bool
  default     = false
}

variable "existing_monitoring_instance_crn" {
  description = "CRN of existing IBM Cloud Monitoring instance. If null and enable_monitoring is true, a new instance will be created."
  type        = string
  default     = null
}

########################################################
# Optional: Security and Compliance Center Workload Protection
########################################################

variable "enable_scc_wp" {
  description = "Enable Security and Compliance Center Workload Protection on all VSIs."
  type        = bool
  default     = false
}

variable "ansible_vault_password" {
  description = "Password for Ansible Vault to encrypt sensitive playbook data. Required if enable_scc_wp is true."
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition = (
      var.ansible_vault_password == null ||
      (length(var.ansible_vault_password) >= 15 &&
        length(var.ansible_vault_password) <= 100 &&
        can(regex("[A-Z]", var.ansible_vault_password)) &&
        can(regex("[a-z]", var.ansible_vault_password)) &&
        can(regex("[0-9]", var.ansible_vault_password)) &&
      can(regex("[!#$%&()*+./:;<=>?@\\[\\]_{|}~-]", var.ansible_vault_password)))
    )
    error_message = "Ansible vault password must be 15-100 characters with at least one uppercase, lowercase, number, and special character."
  }
}