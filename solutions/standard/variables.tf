variable "ibmcloud_api_key" {
  description = "API Key of IBM Cloud Account."
  type        = string
  sensitive   = true
}

variable "iaas_classic_username" {
  description = "IBM Cloud Classic IaaS username. Remove after testing. Todo"
  type        = string
  default = "1d2d5e521b504072bbfa58a5ebf7f03d"
}

variable "iaas_classic_api_key" {
  description = "IBM Cloud Classic IaaS API key. Remove after testing. Todo"
  type        = string
  sensitive   = true
  default = ""
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
  default = "9e666805-b237-4e9b-8f6f-efdb8c4398c7"
}

variable "pi_ssh_public_key_name" {
  description = "Name of the SSH key pair to associate with the instance"
  type        = string
  default = "Permanent-VPC-VM-Key"
}

variable "ssh_private_key" {
  description = "Private SSH key (RSA format) used to login to IBM PowerVS instances. Should match to uploaded public SSH key referenced by 'pi_ssh_public_key_name' which was created previously. The key is temporarily stored and deleted. For more information about SSH keys, see [SSH keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
  type        = string
  sensitive   = true
}

variable "pi_rhel_management_server_type" {
  description = "Server type for the management instance."
  type        = string
  default     = "s922"
}

variable "pi_rhel_image_name" {
  description = "Name of the IBM PowerVS RHEL boot image to use for provisioning the instance. Must reference a valid RHEL image."
  type        = string
  default    = "RHEL9-SP4"
}

variable "pi_aix_image_name" {
  description = "Name of the IBM PowerVS AIX boot image used to deploy and host Oracle Database Appliance."
  type        = string
  default = "7300-03-01"
}

variable "pi_aix_instance" {
  description = "Configuration settings for the IBM PowerVS AIX instance where Oracle will be installed. Includes memory size, number of processors, processor type, and system type."

  type = object({
    memory_size       = number # Memory size in GB
    number_processors = number # Number of virtual processors
    cpu_proc_type     = string # Processor type: shared, capped, or dedicated
    server_type       = string # System type (e.g., s922, e980)
    pin_policy        = string # Pin policy (e.g., hard, soft)
    health_status     = string # Health status (e.g., OK, Warning, Critical)
  })
  default = {
    "memory_size" : "8",
    "number_processors" : "1",
    "cpu_proc_type" : "shared",
    "server_type" : "s922",
    "pin_policy" : "hard",
    "health_status" : "OK"
  }
}

variable "pi_networks" {
  description = "Existing list of private subnet ids to be attached to an instance. The first element will become the primary interface. Run 'ibmcloud pi networks' to list available private subnets."
  type = list(object({
    name = string
    id   = string
  }))
  default = [
  {
    name = "ora_10_80_40"
    id   = "081a5d02-bf8c-4931-aa6a-d04b8146ec6f"
  }#,
 # {
 #   name = ""
 #   id   = ""
 # }
]
}


variable "ibmcloud_cos_configuration" {
  description = "Cloud Object Storage instance containing Oracle installation files that will be downloaded to NFS share. 'db-sw/cos_oracle_database_sw_path' must contain only binaries required for Oracle Database installation. 'grid-sw/cos_oracle_grid_sw_path' must contain only binaries required for oracle grid installation when ASM. Leave it empty when JFS. 'patch/cos_oracle_ru_file_path' must contain only binaries required to apply RU patch.'opatch/cos_oracle_opatch_file_path' must contain only binaries required for opatch minimum version install. The binaries required for installation can be found [here](https://edelivery.oracle.com/osdc/faces/SoftwareDelivery or https://www.oracle.com/database/technologies/oracle19c-aix-193000-downloads.html).Avoid inserting '/' at the beginning for 'cos_oracle_database_sw_path', 'cos_oracle_grid_sw_path' and 'cos_oracle_ru_file_path', and 'cos_oracle_opatch_file_path'. Follow exactly same directory structure as prescribed"
  type = object({
    cos_region                        = string
    cos_bucket_name                   = string
    cos_oracle_database_sw_path       = string
    cos_oracle_grid_sw_path           = optional(string)
    cos_oracle_ru_file_path           = string
    cos_oracle_opatch_file_path       = string
  })
  default = {
    "cos_region":"us-west",
    "cos_bucket_name":"bkt-011",
    "cos_oracle_database_sw_path": "V982583-01_193000_db.zip",
    "cos_oracle_grid_sw_path": "V982588-01_193000_grid.zip",
    "cos_oracle_ru_file_path": "p37641958_190000_AIX64-5L.zip",
    "cos_oracle_opatch_file_path": "p6880880_190000_AIX64-5L.zip"
  }
  validation {
    condition     = var.oracle_install_type == "ASM" ? (var.ibmcloud_cos_configuration.cos_oracle_grid_sw_path != null && length(var.ibmcloud_cos_configuration.cos_oracle_grid_sw_path) > 0) : true
    error_message = "For ASM installation, 'cos_oracle_grid_sw_path' must be provided in 'ibmcloud_cos_configuration'."
  }
}

variable "ibmcloud_cos_service_credentials" {
  description = "IBM Cloud Object Storage instance service credentials to access the bucket in the instance (IBM Cloud > Cloud Object Storage > Instances > cos-instance-name > Service Credentials).[json example of service credential](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-service-credentials)"
  type = object({
    apikey                      = string
    endpoints                   = string
    iam_apikey_description      = string
    iam_apikey_id               = string
    iam_apikey_name             = string
    iam_role_crn                = string
    iam_serviceid_crn           = string
    resource_instance_id        = string
  })
  default =  {
    "apikey": "zVmNQKm3Z3Z4G3lQQhUlTQhUP_QPPQJis4R_lrESk94V",
    "endpoints": "https://control.cloud-object-storage.test.cloud.ibm.com/v2/endpoints",
    "iam_apikey_description": "Auto-generated for key crn:v1:staging:public:cloud-object-storage:global:a/72ddef7673c94603ac4b06b74c426e0a:e1b7c24c-584d-49c0-81f9-2d336ca3569d:resource-key:d6da2bc3-f281-406b-9689-ec8469fd85e3",
    "iam_apikey_id": "ApiKey-d2be8181-8134-40dc-a4f8-f5226238efc2",
    "iam_apikey_name": "sc-002",
    "iam_role_crn": "crn:v1:bluemix:public:iam::::serviceRole:Manager",
    "iam_serviceid_crn": "crn:v1:staging:public:iam-identity::a/72ddef7673c94603ac4b06b74c426e0a::serviceid:ServiceId-72be8856-4c57-4e7e-b51b-e16ba9e369c0",
    "resource_instance_id": "crn:v1:staging:public:cloud-object-storage:global:a/72ddef7673c94603ac4b06b74c426e0a:e1b7c24c-584d-49c0-81f9-2d336ca3569d::"
   }
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
    "name" : "exboot",
    "size" : "40",
    "count" : "1",
    "tier" : "tier1"
  }
}

# 2. oravg
variable "pi_oravg_volume" {
  description = "ORAVG volume configuration"
  type = object({
    name  = string
    size  = string
    count = string
    tier  = string
  })
  default = {
    "name" : "oravg",
    "size" : "200",
    "count" : "1",
    "tier" : "tier1"
  }
}

# 3. DATA diskgroup
variable "pi_data_volume" {
  description = "Disk configuration for ASM"
  type = object({
    name  = string
    size  = string
    count = string
    tier  = string
  })
  default = {
    "name" : "DATA",
    "size" : "20",
    "count" : "4",
    "tier" : "tier1"
  }
}


############################################
# Optional IBM PowerVS Instance Parameters
############################################
variable "pi_user_tags" {
  description = "List of Tag names for IBM Cloud PowerVS instance and volumes. Can be set to null."
  type        = list(string)
  default     = null
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

variable "use_rhel_as_proxy" {
  description = "Whether to use RHEL VM as proxy if it has public internet access. If false, fallback to bastion."
  type        = bool
  default     = false
}

variable "apply_ru" {
  description = "If set to true, ansible play will be executed to preform oracle/grid patch. TODO"
  type        = bool
  default     = true
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