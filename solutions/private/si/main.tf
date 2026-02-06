#############################
# Create RHEL VM
# Create AIX VM
# Initialize RHEL VM
# Initialize AIX VM
# Download Oracle binaries from cos
# Install GRID and RDBMS and Create Oracle Database
#############################

# Create RHEL Management VM

locals {
  nfs_mount = "/repos"

  pi_boot_volume = {
    "name" : "rootvg",
    "size" : "40",
    "count" : "1",
    "tier" : "tier1"
  }

  pi_crsdg_volume = {
    "name" : "CRSDG",
    "size" : "4",
    "count" : "4",
    "tier" : "tier1"
  }

  pi_arc_volume = {
    "name" : "ARCH",
    "size" : "10",
    "count" : "4",
    "tier" : "tier3"
  }

  pi_cpu_map = {
    public  = 0.25
    private = 0.05
  }

  pi_rhel_cpu_cores = lookup(local.pi_cpu_map, var.deployment_type, 0.25)

  pi_aix_cpu_cores = coalesce(
    try(var.pi_aix_instance.number_processors, null),
    lookup(local.pi_cpu_map, var.deployment_type, 0.25)
  )
}

module "pi_instance_rhel" {
  source  = "terraform-ibm-modules/powervs-instance/ibm"
  version = "2.8.6"

  pi_workspace_guid       = var.pi_existing_workspace_guid
  pi_ssh_public_key_name  = var.pi_ssh_public_key_name
  pi_image_id             = var.pi_rhel_image_name
  pi_networks             = var.pi_networks
  pi_instance_name        = "${var.prefix}-mgmt-rhel"
  pi_memory_size          = var.pi_memory_size
  pi_number_of_processors = local.pi_rhel_cpu_cores
  pi_server_type          = var.pi_rhel_management_server_type
  pi_cpu_proc_type        = "shared"
  pi_storage_config = [{
    "name" : "nfs",
    "size" : "50",
    "count" : "1",
    "tier" : "tier3"
    "mount" : local.nfs_mount
  }]

}

# Create AIX VM for Oracle database
module "pi_instance_aix" {
  source  = "terraform-ibm-modules/powervs-instance/ibm"
  version = "2.8.6"

  pi_workspace_guid          = var.pi_existing_workspace_guid
  pi_ssh_public_key_name     = var.pi_ssh_public_key_name
  pi_image_id                = var.pi_aix_image_name
  pi_networks                = var.pi_networks
  pi_instance_name           = "${var.prefix}-ora-aix"
  pi_pin_policy              = var.pi_aix_instance.pin_policy
  pi_server_type             = var.pi_aix_instance.server_type
  pi_number_of_processors    = local.pi_aix_cpu_cores
  pi_memory_size             = var.pi_aix_instance.memory_size
  pi_cpu_proc_type           = var.pi_aix_instance.cpu_proc_type
  pi_boot_image_storage_tier = "tier1"
  pi_user_tags               = var.pi_user_tags
  
  # Storage configuration based on install type - using user-provided variables
  pi_storage_config = (
    var.oracle_install_type == "ASM" ?
    [
      local.pi_boot_volume,
      var.pi_oravg_volume,        # Oracle software VG
      local.pi_crsdg_volume,      # ASM CRSDG
      var.pi_data_volume,         # ASM DATA diskgroup
      var.pi_redo_volume,         # ASM REDO diskgroup
      local.pi_arc_volume         # ASM ARCH diskgroup
    ] :
    [
      local.pi_boot_volume,
      var.pi_oravg_volume,        # Oracle software VG
      var.pi_data_volume,         # JFS2 DATAVG (for datafiles)
      var.pi_redo_volume,         # JFS2 REDOVG (for redo + control files)
      local.pi_arc_volume         # JFS2 ARCHVG (for archives)
    ]
  )
}

###########################################################
# Ansible Host setup and configure as Proxy, NTP and DNS
###########################################################

locals {
  network_services_config = {
    squid = {
      enable     = true
      squid_port = "3128"
    }
  }
}

module "pi_instance_rhel_init" {
  source     = "../../../modules/ansible"
  depends_on = [module.pi_instance_rhel]

  deployment_type        = var.deployment_type
  bastion_host_ip        = var.bastion_host_ip
  ansible_host_or_ip     = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key        = var.ssh_private_key
  configure_ansible_host = true
  squid_server_ip        = var.squid_server_ip

  src_script_template_name = "configure-rhel-management/ansible_exec.sh.tftpl"
  dst_script_file_name     = "configure-rhel-management.sh"

  src_playbook_template_name = "configure-rhel-management/playbook-configure-network-services.yml.tftpl"
  dst_playbook_file_name     = "configure-rhel-management-playbook.yml"

  playbook_template_vars = {
    server_config     = jsonencode(local.network_services_config)
    pi_storage_config = jsonencode(module.pi_instance_rhel.pi_storage_configuration)
    nfs_config = jsonencode({
      nfs = {
        enable      = true
        directories = [local.nfs_mount]
      }
    })
  }

  src_inventory_template_name = "inventory.tftpl"
  dst_inventory_file_name     = "configure-rhel-management-inventory"
  inventory_template_vars = {
    host_or_ip = module.pi_instance_rhel.pi_instance_primary_ip
  }
}

###########################################################
# AIX Initialization
###########################################################

locals {
  squid_server_ip = var.squid_server_ip
  playbook_aix_init_vars = {
    PROXY_IP_PORT          = "${local.squid_server_ip}:3128"
    NO_PROXY               = var.no_proxy_list
    ORA_NFS_HOST           = module.pi_instance_aix.pi_instance_primary_ip
    ORA_NFS_DEVICE         = local.nfs_mount
    EXTEND_ROOT_VOLUME_WWN = module.pi_instance_aix.pi_storage_configuration[0].wwns
    AIX_INIT_MODE = ""
    ROOT_PASSWORD = ""
  }

}

module "pi_instance_aix_init" {
  source     = "../../../modules/ansible"
  depends_on = [module.pi_instance_rhel_init]
  
  deployment_type        = var.deployment_type
  bastion_host_ip        = var.bastion_host_ip
  ansible_host_or_ip     = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key        = var.ssh_private_key
  configure_ansible_host = false
  squid_server_ip        = local.squid_server_ip

  src_script_template_name = "aix-init/ansible_exec.sh.tftpl"
  dst_script_file_name     = "aix_init.sh"

  src_playbook_template_name = "aix-init/playbook-aix-init.yml.tftpl"
  dst_playbook_file_name     = "aix-init-playbook.yml"
  playbook_template_vars     = local.playbook_aix_init_vars

  src_inventory_template_name = "inventory.tftpl"
  dst_inventory_file_name     = "aix-init-inventory"
  inventory_template_vars     = { "host_or_ip" : module.pi_instance_aix.pi_instance_primary_ip }

}

######################################################
# COS Service credentials
# Download Oracle binaries
# from IBM Cloud Object Storage(COS) to Ansible host
# host NFS mount point
######################################################

locals {
  cos_service_credentials  = jsondecode(var.ibmcloud_cos_service_credentials)
  cos_apikey               = local.cos_service_credentials.apikey
  cos_resource_instance_id = local.cos_service_credentials.resource_instance_id
}

locals {

  ibmcloud_cos_oracle_configuration = {
    cos_apikey               = local.cos_apikey
    cos_region               = var.ibmcloud_cos_configuration.cos_region
    cos_resource_instance_id = local.cos_resource_instance_id
    cos_bucket_name          = var.ibmcloud_cos_configuration.cos_bucket_name
    cos_dir_name             = var.ibmcloud_cos_configuration.cos_oracle_database_sw_path
    download_dir_path        = local.nfs_mount
  }

  ibmcloud_cos_grid_configuration = {
    cos_apikey               = local.cos_apikey
    cos_region               = var.ibmcloud_cos_configuration.cos_region
    cos_resource_instance_id = local.cos_resource_instance_id
    cos_bucket_name          = var.ibmcloud_cos_configuration.cos_bucket_name
    cos_dir_name             = var.ibmcloud_cos_configuration.cos_oracle_grid_sw_path
    download_dir_path        = local.nfs_mount
  }

  ibmcloud_cos_patch_configuration = {
    cos_apikey               = local.cos_apikey
    cos_region               = var.ibmcloud_cos_configuration.cos_region
    cos_resource_instance_id = local.cos_resource_instance_id
    cos_bucket_name          = var.ibmcloud_cos_configuration.cos_bucket_name
    cos_dir_name             = var.ibmcloud_cos_configuration.cos_oracle_ru_file_path
    download_dir_path        = local.nfs_mount
  }

  ibmcloud_cos_opatch_configuration = {
    cos_apikey               = local.cos_apikey
    cos_region               = var.ibmcloud_cos_configuration.cos_region
    cos_resource_instance_id = local.cos_resource_instance_id
    cos_bucket_name          = var.ibmcloud_cos_configuration.cos_bucket_name
    cos_dir_name             = var.ibmcloud_cos_configuration.cos_oracle_opatch_file_path
    download_dir_path        = local.nfs_mount
  }
}

module "ibmcloud_cos_oracle" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.pi_instance_rhel_init]

  access_host_or_ip          = var.bastion_host_ip
  target_server_ip           = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_oracle_configuration
}

module "ibmcloud_cos_patch" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_oracle]

  access_host_or_ip          = var.bastion_host_ip
  target_server_ip           = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_patch_configuration
}

module "ibmcloud_cos_opatch" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_patch]

  access_host_or_ip          = var.bastion_host_ip
  target_server_ip           = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_opatch_configuration
}

module "ibmcloud_cos_grid" {
  source     = "../../../modules/ibmcloud-cos"
  depends_on = [module.ibmcloud_cos_opatch]
  count      = var.oracle_install_type == "ASM" ? 1 : 0

  access_host_or_ip          = var.bastion_host_ip
  target_server_ip           = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_grid_configuration
}


###########################################################
# Oracle GRID Installation on AIX
###########################################################

locals {
  # Calculate total sizes from user variables for passing to Ansible
  # Each volume object has: size (per disk) and count (number of disks)
  
  # Calculate total size: size per disk * count
  oravg_total_size = tonumber(var.pi_oravg_volume.size) * tonumber(var.pi_oravg_volume.count)
  data_total_size  = tonumber(var.pi_data_volume.size) * tonumber(var.pi_data_volume.count)
  redo_total_size  = tonumber(var.pi_redo_volume.size) * tonumber(var.pi_redo_volume.count)
  arch_total_size  = tonumber(local.pi_arc_volume.size) * tonumber(local.pi_arc_volume.count)

  playbook_oracle_install_vars = {
    ORA_NFS_HOST        = module.pi_instance_rhel.pi_instance_primary_ip
    ORA_NFS_DEVICE      = local.nfs_mount
    DATABASE_SW         = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_database_sw_path}"
    GRID_SW             = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_grid_sw_path}"
    RU_FILE             = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_ru_file_path}"
    OPATCH_FILE         = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_opatch_file_path}"
    ORA_SID             = var.ora_sid
    ORACLE_INSTALL_TYPE = var.oracle_install_type
    ORA_DB_PASSWORD     = var.ora_db_password
    REDOLOG_SIZE_IN_MB  = var.redolog_size_in_mb
    # Pass calculated sizes to Ansible (subtract 1GB for VG overhead)
    ORAVG_SIZE          = tostring(local.oravg_total_size - 1)
    DATA_SIZE           = tostring(local.data_total_size - 1)
    REDO_SIZE           = tostring(local.redo_total_size - 1)
    ARCH_SIZE           = tostring(local.arch_total_size - 1)
  }
}

module "oracle_install" {
  source     = "../../../modules/ansible"
  depends_on = [module.ibmcloud_cos_grid, module.pi_instance_aix_init]

  deployment_type        = var.deployment_type
  bastion_host_ip        = var.bastion_host_ip
  ansible_host_or_ip     = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key        = var.ssh_private_key
  configure_ansible_host = false
  squid_server_ip        = local.squid_server_ip

  src_script_template_name = "oracle-grid-install/ansible_exec.sh.tftpl"
  dst_script_file_name     = "oracle_install.sh"

  src_playbook_template_name = "oracle-grid-install/playbook-install-oracle-grid.yml.tftpl"
  dst_playbook_file_name     = "playbook-install-oracle-grid.yml"
  playbook_template_vars     = local.playbook_oracle_install_vars

  src_inventory_template_name = "inventory.tftpl"
  dst_inventory_file_name     = "oracle-grid-install-inventory"
  inventory_template_vars     = { "host_or_ip" : module.pi_instance_aix.pi_instance_primary_ip }
}
