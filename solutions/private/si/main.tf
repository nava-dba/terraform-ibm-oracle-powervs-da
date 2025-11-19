#############################
# Create RHEL VM
# Create AIX VM
# Initialize RHEL VM
# Intitialize AIX VM
# Download Oracle binaries from cos
# Install GRID and RDBMS and Create Oracle Database
#############################

# Create RHEL Management VM

locals {
  nfs_mount = "/repos"
}

module "pi_instance_rhel" {
  source  = "terraform-ibm-modules/powervs-instance/ibm"
  version = "2.7.0"

  pi_workspace_guid       = var.pi_existing_workspace_guid
  pi_ssh_public_key_name  = var.pi_ssh_public_key_name
  pi_image_id             = var.pi_rhel_image_name
  pi_networks             = var.pi_networks
  pi_instance_name        = "${var.prefix}-mgmt-rhel"
  pi_memory_size          = "4"
  pi_number_of_processors = ".05"
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
  version = "2.7.0"

  pi_workspace_guid          = var.pi_existing_workspace_guid
  pi_ssh_public_key_name     = var.pi_ssh_public_key_name
  pi_image_id                = var.pi_aix_image_name
  pi_networks                = var.pi_networks
  pi_instance_name           = "${var.prefix}-ora-aix"
  pi_pin_policy              = var.pi_aix_instance.pin_policy
  pi_server_type             = var.pi_aix_instance.server_type
  pi_number_of_processors    = var.pi_aix_instance.number_processors
  pi_memory_size             = var.pi_aix_instance.memory_size
  pi_cpu_proc_type           = var.pi_aix_instance.cpu_proc_type
  pi_boot_image_storage_tier = "tier1"
  pi_user_tags               = var.pi_user_tags
  pi_storage_config = (
  var.oracle_install_type == "ASM" ?
  [var.pi_boot_volume, var.pi_oravg_volume, var.pi_crsdg_volume, var.pi_data_volume, var.pi_redo_volume] :
  [var.pi_boot_volume, var.pi_oravg_volume, var.pi_datavg_volume]
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
    dns = {
      enable      = true
      dns_servers = "161.26.0.7; 161.26.0.8; 9.9.9.9;"
    }
    ntp = {
      enable = true
    }
  }
}

module "pi_instance_rhel_init" {
  source     = "../../../modules/ansible"
  depends_on = [module.pi_instance_rhel]

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
    server_config    = jsonencode(local.network_services_config)
    pi_storage_config = jsonencode(module.pi_instance_rhel.pi_storage_configuration)
    nfs_config        = jsonencode({
      nfs = {
        enable      = true
        directories = [local.nfs_mount]
      }
    })
  }

  src_inventory_template_name = "inventory.tftpl"
  dst_inventory_file_name     = "configure-rhel-management-inventory"
  inventory_template_vars     = {
    host_or_ip = module.pi_instance_rhel.pi_instance_primary_ip
  }
}

###########################################################
# AIX Initialization
###########################################################

locals {
  squid_server_ip = var.squid_server_ip
  playbook_aix_init_vars = {
    PROXY_IP_PORT  = "${local.squid_server_ip}:3128"
    NO_PROXY       = "TODO"
    ORA_NFS_HOST   = module.pi_instance_aix.pi_instance_primary_ip
    ORA_NFS_DEVICE = local.nfs_mount
    EXTEND_ROOT_VOLUME_WWN = module.pi_instance_aix.pi_storage_configuration[0].wwns
  }

}

module "pi_instance_aix_init" {
  source     = "../../../modules/ansible"
  depends_on = [module.pi_instance_rhel_init]

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
    download_dir_path        =  "${local.nfs_mount}"
  }

  ibmcloud_cos_grid_configuration = {
    cos_apikey               = local.cos_apikey
    cos_region               = var.ibmcloud_cos_configuration.cos_region
    cos_resource_instance_id = local.cos_resource_instance_id
    cos_bucket_name          = var.ibmcloud_cos_configuration.cos_bucket_name
    cos_dir_name             = var.ibmcloud_cos_configuration.cos_oracle_grid_sw_path
    download_dir_path        =  "${local.nfs_mount}"
  }

  ibmcloud_cos_patch_configuration = {
    cos_apikey               = local.cos_apikey
    cos_region               = var.ibmcloud_cos_configuration.cos_region
    cos_resource_instance_id = local.cos_resource_instance_id
    cos_bucket_name          = var.ibmcloud_cos_configuration.cos_bucket_name
    cos_dir_name             = var.ibmcloud_cos_configuration.cos_oracle_ru_file_path
    download_dir_path        =  "${local.nfs_mount}"
  }

  ibmcloud_cos_opatch_configuration = {
    cos_apikey               = local.cos_apikey
    cos_region               = var.ibmcloud_cos_configuration.cos_region
    cos_resource_instance_id = local.cos_resource_instance_id
    cos_bucket_name          = var.ibmcloud_cos_configuration.cos_bucket_name
    cos_dir_name             = var.ibmcloud_cos_configuration.cos_oracle_opatch_file_path
    download_dir_path        =  "${local.nfs_mount}"
  }
}

module "ibmcloud_cos_oracle" {
  source = "../../../modules/ibmcloud-cos"
  depends_on = [module.pi_instance_rhel_init]

  access_host_or_ip          = var.bastion_host_ip
  target_server_ip           = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_oracle_configuration
}

module "ibmcloud_cos_patch" {
  source = "../../../modules/ibmcloud-cos"
  depends_on = [ module.ibmcloud_cos_oracle ]

  access_host_or_ip          = var.bastion_host_ip
  target_server_ip           = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_patch_configuration
}

module "ibmcloud_cos_opatch" {
  source = "../../../modules/ibmcloud-cos"
  depends_on = [ module.ibmcloud_cos_patch ]

  access_host_or_ip          = var.bastion_host_ip
  target_server_ip           = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_opatch_configuration
}

module "ibmcloud_cos_grid" {
  source = "../../../modules/ibmcloud-cos"
  depends_on = [ module.ibmcloud_cos_opatch ]
  count = var.oracle_install_type == "ASM" ? 1 : 0

  access_host_or_ip          = var.bastion_host_ip
  target_server_ip           = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key            = var.ssh_private_key
  ibmcloud_cos_configuration = local.ibmcloud_cos_grid_configuration
}


###########################################################
# Oracle GRID Installation on AIX
###########################################################

locals {
  playbook_oracle_install_vars = {
    ORA_NFS_HOST   = module.pi_instance_rhel.pi_instance_primary_ip
    ORA_NFS_DEVICE =  local.nfs_mount
    DATABASE_SW    = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_database_sw_path}"
    GRID_SW        = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_grid_sw_path}"
    RU_FILE        = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_ru_file_path}"
    OPATCH_FILE    = "${local.nfs_mount}/${var.ibmcloud_cos_configuration.cos_oracle_opatch_file_path}"
    ORA_SID        = var.ora_sid        
    ORACLE_INSTALL_TYPE = var.oracle_install_type
    ORA_DB_PASSWORD= var.ora_db_password
  }
}

module "oracle_install" {
  source     = "../../../modules/ansible"
    depends_on = [  module.ibmcloud_cos_grid, module.pi_instance_aix_init]
    
  bastion_host_ip        = var.bastion_host_ip
  ansible_host_or_ip     = module.pi_instance_rhel.pi_instance_primary_ip
  ssh_private_key        = var.ssh_private_key
  configure_ansible_host = false
  squid_server_ip               = local.squid_server_ip

  src_script_template_name = "oracle-grid-install/ansible_exec.sh.tftpl"
  dst_script_file_name     = "oracle_install.sh"

  src_playbook_template_name = "oracle-grid-install/playbook-install-oracle-grid.yml.tftpl"
  dst_playbook_file_name     = "playbook-install-oracle-grid.yml"
  playbook_template_vars     = local.playbook_oracle_install_vars

  src_inventory_template_name = "inventory.tftpl"
  dst_inventory_file_name     = "oracle-grid-install-inventory"
  inventory_template_vars     = { "host_or_ip" : module.pi_instance_aix.pi_instance_primary_ip }
}
